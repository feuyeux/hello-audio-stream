import { Map } from "mmap-io";
import { promises as fs } from "fs";
import { createLogger } from "pino";

const logger = createLogger({ level: "debug" });

const DEFAULT_PAGE_SIZE = 64 * 1024 * 1024;
const MAX_CACHE_SIZE = 2 * 1024 * 1024 * 1024;

export class MmapCache {
  constructor(path) {
    this.path = path;
    this.map = null;
    this.size = 0;
    this.is_open = false;
  }

  async create(path, initialSize = 0) {
    try {
      logger.debug(
        `Creating mmap file: ${path} with initial size: ${initialSize}`,
      );

      if (
        await fs
          .access(path)
          .then(() => true)
          .catch(() => false)
      ) {
        await fs.unlink(path);
      }

      const fileHandle = await fs.open(path, "w+");
      if (initialSize > 0) {
        await fileHandle.truncate(initialSize);
        this.size = initialSize;
      } else {
        this.size = 0;
      }
      await fileHandle.close();

      if (this.size > 0) {
        await this.mapFile();
      }

      this.is_open = true;
      logger.debug(`Created mmap file: ${path} with size: ${initialSize}`);
      return true;
    } catch (error) {
      logger.error(`Error creating file ${path}: ${error.message}`);
      return false;
    }
  }

  async open(path) {
    try {
      logger.debug(`Opening mmap file: ${path}`);

      const exists = await fs
        .access(path)
        .then(() => true)
        .catch(() => false);
      if (!exists) {
        logger.error(`File does not exist: ${path}`);
        return false;
      }

      const stats = await fs.stat(path);
      this.size = stats.size;

      if (this.size > 0) {
        await this.mapFile();
      }

      this.is_open = true;
      logger.debug(`Opened mmap file: ${path} with size: ${this.size}`);
      return true;
    } catch (error) {
      logger.error(`Error opening file ${path}: ${error.message}`);
      return false;
    }
  }

  async close() {
    if (this.is_open) {
      await this.unmapFile();
      logger.debug(`Closed mmap file: ${this.path}`);
    }
  }

  async write(offset, data) {
    try {
      if (!this.is_open || this.map === null) {
        const initialSize = offset + data.length;
        if (!(await this.create(this.path, initialSize))) {
          return 0;
        }
      }

      const requiredSize = offset + data.length;
      if (requiredSize > this.size) {
        if (!(await this.resize(requiredSize))) {
          logger.error("Failed to resize file for write operation");
          return 0;
        }
      }

      this.map.set(data, offset);

      logger.debug(
        `Wrote ${data.length} bytes to ${this.path} at offset ${offset}`,
      );
      return data.length;
    } catch (error) {
      logger.error(
        `Error writing to mapped file ${this.path}: ${error.message}`,
      );
      return 0;
    }
  }

  async read(offset, length) {
    try {
      if (!this.is_open || this.map === null) {
        logger.debug(
          `File not open, attempting to open for reading: ${this.path}`,
        );
        if (!(await this.open(this.path))) {
          logger.error(`Failed to open file for reading: ${this.path}`);
          return Buffer.alloc(0);
        }
      }

      if (offset >= this.size) {
        logger.debug(
          `Read offset ${offset} at or beyond file size ${this.size} - end of file`,
        );
        return Buffer.alloc(0);
      }

      const actualLength = Math.min(length, this.size - offset);
      const data = this.map.subarray(offset, offset + actualLength);

      logger.debug(
        `Read ${actualLength} bytes from ${this.path} at offset ${offset}`,
      );
      return data;
    } catch (error) {
      logger.error(
        `Error reading from mapped file ${this.path}: ${error.message}`,
      );
      return Buffer.alloc(0);
    }
  }

  getSize() {
    return this.size;
  }

  getPath() {
    return this.path;
  }

  isOpen() {
    return this.is_open;
  }

  async resize(newSize) {
    try {
      if (!this.is_open) {
        logger.error(`File not open for resize: ${this.path}`);
        return false;
      }

      if (newSize === this.size) {
        return true;
      }

      await this.unmapFile();
      const fileHandle = await fs.open(this.path, "r+");
      await fileHandle.truncate(newSize);
      await fileHandle.close();
      this.size = newSize;

      if (this.size > 0) {
        await this.mapFile();
      }

      logger.debug(
        `Resized and remapped file ${this.path} to ${newSize} bytes`,
      );
      return true;
    } catch (error) {
      logger.error(`Error resizing file ${this.path}: ${error.message}`);
      return false;
    }
  }

  async finalize(finalSize) {
    try {
      if (!this.is_open) {
        logger.warn(`File not open for finalization: ${this.path}`);
        return false;
      }

      if (!(await this.resize(finalSize))) {
        logger.error(`Failed to resize file during finalization: ${this.path}`);
        return false;
      }

      if (this.map !== null) {
        this.map.flush();
      }

      logger.debug(`Finalized file: ${this.path} with size: ${finalSize}`);
      return true;
    } catch (error) {
      logger.error(`Error finalizing file ${this.path}: ${error.message}`);
      return false;
    }
  }

  async mapFile() {
    try {
      this.map = await Map.map(this.path, 0, this.size);
      logger.debug(
        `Successfully mapped file: ${this.path} (${this.size} bytes)`,
      );
    } catch (error) {
      logger.error(`Error mapping file ${this.path}: ${error.message}`);
      throw error;
    }
  }

  async unmapFile() {
    if (this.map !== null) {
      this.map.flush();
      await this.map.close();
      this.map = null;
    }

    this.is_open = false;
  }
}
