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

# Example
If input string = 'myString', multiple outputs of the same input produce different results:  
DECLARE @originalstring varchar(128);  
DECLARE @cipheredstring = varchar(256);  
SET @originalstring = 'myString'  
EXEC elevant.GetCipherString @originalstring, @ciphered = @cipherstring OUTPUT  
SELECT @cipheredstring AS CipheredString  

47473B3A7B3B753A3B3B623B606F757B473A7262706D28287D253D51733A3363653477757C45203B554C6A6A356136502E626A5E59275E24755E2B5B71796A377E363B54322A543C377C7C7753432C642E683A5B6E4B6947374F477523203751246F5B6F797276355973574D727A69576E7B7C6B20746E7C747A765734645138

EXEC elevant.GetCipherString @originalstring, @ciphered = @cipherstring OUTPUT  
SELECT @cipheredstring AS CipheredString

60425858796F3C6F46465846746F453C42604E587964432124523F2D72366B4152307F3B395D683051306345775D715F7D4B653A387843356C4D3B337D5276475633505E6D7166397B793558702A6B68477E466526626C5E7A482878386A7E734F31256F463236315A6E7A5B58222E5B616F28535F7E637B374A7362792D203E

EXEC elevant.GetCipherString @originalstring, @ciphered = @cipherstring OUTPUT  
SELECT @cipheredstring AS CipheredString

4771473B3E3B6E4A3B3B683B3A473C4A6E7174683E6C2727415959485D76444F3B29732F4C292D767A3D4550484F345235416C47254F286C3C31794F737A2F7B2344767A6B5F465F5F7B642D3C312742702E58653C3F6A576175773F3D537331315252646A4931485A30295B532F4D4A623B78746578582845254D7129756823
