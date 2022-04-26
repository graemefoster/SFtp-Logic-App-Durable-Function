# SFtp connector in Azure Logic App

## Learnings

Internally uses SSH.Net to connect to the SFTP Server. Trial and error using the library to generate a key-pair that the library liked. In the end I used
``` ssh-keygen -m PEM -t rsa -b 4096 -C fred ```
to generate the key-pair.
