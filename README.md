# **KeySafe: Secure key store**

###### OSS-Project for IBMi

This program stores different login data in different catalogues encrypted by db2 crypto-services. Please also use telnet over tls :-)

To create this program plase create a new schema on your IBMi with the name "KEYSAFE".
You need a journal and journalreceiver for the db2 crypt functions.
Also create the source-container (qcmdsrc, qddssrc, qrpglecpy, qrpglesrc). I have used the record-length of 112.

Create the tables and views.

Copy the sources to the sourcecontainer (qrpglesrc/qcmdsrc/etc) and compile them via pdm-option "14"

![LOGIN-SCREEN](https://github.com/PantalonOrange/KEYSAFE/blob/master/keysafe_login.png)

![LOGIN-MAIN](https://github.com/PantalonOrange/KEYSAFE/blob/master/keysafe_main.png)

