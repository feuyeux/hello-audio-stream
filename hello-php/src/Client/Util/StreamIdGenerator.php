<?php

namespace AudioStreamClient\Util;

/**
 * Stream ID generator for creating unique stream identifiers.
 * Matches the Java StreamIdGenerator interface.
 */
class StreamIdGenerator
{
    private const DEFAULT_PREFIX = 'stream';
    
    /**
     * Generate a unique stream ID with default prefix "stream".
     *
     * @return string Stream ID in format "stream-{uuid}"
     */
    public static function generate(): string
    {
        return self::generateWithPrefix(self::DEFAULT_PREFIX);
    }
    
    /**
     * Generate a unique stream ID with custom prefix.
     *
     * @param string $prefix Prefix for the stream ID
     * @return string Stream ID in format "{prefix}-{uuid}"
     */
    public static function generateWithPrefix(string $prefix): string
    {
        if (empty($prefix)) {
            $prefix = self::DEFAULT_PREFIX;
        }
        
        $uuid = self::generateUUID();
        $streamId = $prefix . '-' . $uuid;
        
        return $streamId;
    }
    
    /**
     * Generate a short stream ID (8 characters).
     *
     * @return string Short stream ID in format "stream-{short-uuid}"
     */
    public static function generateShort(): string
    {
        return self::generateShortWithPrefix(self::DEFAULT_PREFIX);
    }
    
    /**
     * Generate a short stream ID with custom prefix.
     *
     * @param string $prefix Prefix for the stream ID
     * @return string Short stream ID in format "{prefix}-{short-uuid}"
     */
    public static function generateShortWithPrefix(string $prefix): string
    {
        if (empty($prefix)) {
            $prefix = self::DEFAULT_PREFIX;
        }
        
        $uuid = substr(self::generateUUID(), 0, 8);
        $streamId = $prefix . '-' . $uuid;
        
        return $streamId;
    }
    
    /**
     * Validate a stream ID format.
     *
     * @param string $streamId Stream ID to validate
     * @return bool True if valid format
     */
    public static function validate(string $streamId): bool
    {
        if (empty($streamId)) {
            return false;
        }
        
        $pattern = '/^[a-zA-Z0-9_-]+-[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/';
        return preg_match($pattern, $streamId) === 1;
    }
    
    /**
     * Validate a short stream ID format.
     *
     * @param string $streamId Stream ID to validate
     * @return bool True if valid short format
     */
    public static function validateShort(string $streamId): bool
    {
        if (empty($streamId)) {
            return false;
        }
        
        $pattern = '/^[a-zA-Z0-9_-]+-[a-f0-9]{8}$/';
        return preg_match($pattern, $streamId) === 1;
    }
    
    /**
     * Extract the prefix from a stream ID.
     *
     * @param string $streamId Stream ID
     * @return string|null Prefix, or null if invalid format
     */
    public static function extractPrefix(string $streamId): ?string
    {
        if (empty($streamId)) {
            return null;
        }
        
        $dashPos = strpos($streamId, '-');
        if ($dashPos !== false && $dashPos > 0) {
            return substr($streamId, 0, $dashPos);
        }
        
        return null;
    }
    
    /**
     * Extract the UUID part from a stream ID.
     *
     * @param string $streamId Stream ID
     * @return string|null UUID string, or null if invalid format
     */
    public static function extractUuid(string $streamId): ?string
    {
        if (empty($streamId)) {
            return null;
        }
        
        $dashPos = strpos($streamId, '-');
        if ($dashPos !== false && $dashPos < strlen($streamId) - 1) {
            return substr($streamId, $dashPos + 1);
        }
        
        return null;
    }
    
    /**
     * Generate a UUID v4 string.
     *
     * @return string UUID string
     */
    private static function generateUUID(): string
    {
        $data = random_bytes(16);
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40); // set version to 0100
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80); // set bits 6-7 to 10
        
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
}