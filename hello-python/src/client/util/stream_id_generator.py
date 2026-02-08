"""Stream ID generator for creating unique stream identifiers."""

import uuid
import re
from typing import Optional


class StreamIdGenerator:
    """Stream ID generator for creating unique stream identifiers.
    
    Matches the Java StreamIdGenerator interface.
    """
    
    def __init__(self):
        self.default_prefix = "stream"
        self.stream_id_pattern = re.compile(r'^[a-zA-Z0-9_-]+-[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$')
    
    def generate(self) -> str:
        """Generate a unique stream ID with default prefix "stream".
        
        Returns:
            stream ID in format "stream-{uuid}"
        """
        return self.generate_with_prefix(self.default_prefix)
    
    def generate_with_prefix(self, prefix: str) -> str:
        """Generate a unique stream ID with custom prefix.
        
        Args:
            prefix: prefix for the stream ID
            
        Returns:
            stream ID in format "{prefix}-{uuid}"
        """
        if not prefix:
            prefix = self.default_prefix
        
        stream_id = f"{prefix}-{str(uuid.uuid4())}"
        return stream_id
    
    def generate_short(self) -> str:
        """Generate a short stream ID (8 characters).
        
        Returns:
            short stream ID in format "stream-{short-uuid}"
        """
        return self.generate_short_with_prefix(self.default_prefix)
    
    def generate_short_with_prefix(self, prefix: str) -> str:
        """Generate a short stream ID with custom prefix.
        
        Args:
            prefix: prefix for the stream ID
            
        Returns:
            short stream ID in format "{prefix}-{short-uuid}"
        """
        if not prefix:
            prefix = self.default_prefix
        
        short_uuid = str(uuid.uuid4()).replace('-', '')[:8]
        stream_id = f"{prefix}-{short_uuid}"
        return stream_id
    
    def validate(self, stream_id: str) -> bool:
        """Validate a stream ID format.
        
        Args:
            stream_id: stream ID to validate
            
        Returns:
            True if valid format
        """
        if not stream_id:
            return False
        
        # Check if it matches the expected pattern
        is_valid = bool(self.stream_id_pattern.match(stream_id))
        
        return is_valid
    
    def validate_short(self, stream_id: str) -> bool:
        """Validate a short stream ID format.
        
        Args:
            stream_id: stream ID to validate
            
        Returns:
            True if valid short format
        """
        if not stream_id:
            return False
        
        # Check if it matches the short pattern: prefix-8chars
        short_pattern = re.compile(r'^[a-zA-Z0-9_-]+-[a-f0-9]{8}$')
        is_valid = bool(short_pattern.match(stream_id))
        
        return is_valid
    
    def extract_prefix(self, stream_id: str) -> Optional[str]:
        """Extract the prefix from a stream ID.
        
        Args:
            stream_id: stream ID
            
        Returns:
            prefix, or None if invalid format
        """
        if not stream_id:
            return None
        
        dash_index = stream_id.find('-')
        if dash_index > 0:
            return stream_id[:dash_index]
        
        return None
    
    def extract_uuid(self, stream_id: str) -> Optional[str]:
        """Extract the UUID part from a stream ID.
        
        Args:
            stream_id: stream ID
            
        Returns:
            UUID string, or None if invalid format
        """
        if not stream_id:
            return None
        
        dash_index = stream_id.find('-')
        if dash_index > 0 and dash_index < len(stream_id) - 1:
            return stream_id[dash_index + 1:]
        
        return None


# Convenience function for quick stream ID generation
def generate_stream_id(prefix: str = "stream") -> str:
    """Generate a stream ID with optional prefix.
    
    Args:
        prefix: prefix for the stream ID (default: "stream")
        
    Returns:
        stream ID in format "{prefix}-{uuid}"
    """
    generator = StreamIdGenerator()
    return generator.generate_with_prefix(prefix)
