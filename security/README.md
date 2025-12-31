# Security Module
This folder contains a string-obfuscation routine.

Each file defines exactly one SQL Server object and is named to match the object
it creates, enabling straightforward review, deployment, and versioning.

Cross-language cipher compatibility with corresponding VBA and Python implementations enabling use across the application stack:
- "elevantcoding/vba-methods/security/StringCipher.bas"
- "elevantcoding/python-methods/security/cipher.py"

# Important: Byte-Safe Design
All cipher operations intentionally use `VARCHAR` instead of `NVARCHAR`.  
Mixing VARCHAR and NVARCHAR caused representation mismatch, which produced incorrect output.

# Example
If input string = 'myString', multiple outputs of the same input produce different results:  
DECLARE @originalstring varchar(128);  
DECLARE @cipheredstring = varchar(256);  
SET @originalstring = 'myString'  
EXEC elevant.GetCipherString @originalstring, @ciphered = @cipherstring OUTPUT  
SELECT @cipheredstring AS CipheredString  

55556577443F775B5C5C3B5C445B42773F65553B716B24754254484A3936294A324A776B6F4E654D206E4443734C5C536F784A224B4C3631556579407273512C6C347E2F42323365757E287451702B697B5E2D415D496F3C29207D5454342633203925647343766B6A5C2C3B23283F47694450494124533F76225A724B3E3871

EXEC elevant.GetCipherString @originalstring, @ciphered = @cipherstring OUTPUT  
SELECT @cipheredstring AS CipheredString

60425858796F3C6F46465846746F453C42604E587964432124523F2D72366B4152307F3B395D683051306345775D715F7D4B653A387843356C4D3B337D5276475633505E6D7166397B793558702A6B68477E466526626C5E7A482878386A7E734F31256F463236315A6E7A5B58222E5B616F28535F7E637B374A7362792D203E

EXEC elevant.GetCipherString @originalstring, @ciphered = @cipherstring OUTPUT  
SELECT @cipheredstring AS CipheredString

4848566E6E6B6B5F484851484A5F746B476E7A5156666A657E5B36774A5F56335C517D515974757274374B564A3D5C547E2C3455697C4B5E64293342706764263A5463752023595B4B7E273971756B5C25207A5C486D6F357449325D2B71532D2E62346D7130245649526C5927717E476D512B58486A22706C74255528602761
