# Security Module
This folder contains cryptographic and string-obfuscation routines.

Each file defines exactly one SQL Server object and is named to match the object
it creates, enabling straightforward review, deployment, and versioning.

Cross-language cipher compatibility with corresponding VBA and Python implementations enables deterministic encoding and decoding across the application stack:
- "elevantcoding/vba-methods/security/StringCipher.bas"
- "elevantcoding/python-methods/security/cipher.py"

# Important: Byte-Safe Design
All cryptographic operations intentionally use `VARCHAR` instead of `NVARCHAR`.  
Mixing VARCHAR and NVARCHAR caused representation mismatch, which produced incorrect output.
