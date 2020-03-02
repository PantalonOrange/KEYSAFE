**FREE
//- Copyright (c) 2020 Christian Brunner
//-
//- Permission is hereby granted, free of charge, to any person obtaining a copy
//- of this software and associated documentation files (the "Software"), to deal
//- in the Software without restriction, including without limitation the rights
//- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//- copies of the Software, and to permit persons to whom the Software is
//- furnished to do so, subject to the following conditions:

//- The above copyright notice and this permission notice shall be included in all
//- copies or substantial portions of the Software.

//- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//- SOFTWARE.

/IF DEFINED (KEYSAFE_H)
/EOF
/ENDIF

/DEFINE KEYSAFE_H

/INCLUDE KEYSAFE/QRPGLECPY,PSDS
/INCLUDE KEYSAFE/QRPGLECPY,BOOLIC
/INCLUDE KEYSAFE/QRPGLECPY,HEX_COLORS

DCL-C FM_A 'A';
DCL-C FM_END '*';
DCL-C MAX_RECORDS 9999;

DCL-S AC_RecordNumber UNS(10) INZ;
DCL-S W2C_RecordNumber UNS(10) INZ;
DCL-S PgmQueue CHAR(10) INZ('MAIN');
DCL-S CallStack INT(10) INZ;

DCL-DS This QUALIFIED;
 PictureControl CHAR(1) INZ(FM_A);
 Loop IND INZ(TRUE);
 RecordsFound INT(10) INZ;
 GlobalMessage CHAR(130) INZ;
 CatalogueGUID CHAR(32) INZ;
 CatalogueName CHAR(40) INZ;
END-DS;

DCL-DS WSDS QUALIFIED;
 Exit IND POS(3);
 SearchEntry IND POS(4);
 Refresh IND POS(5);
 NewEntry IND POS(6);
 CommandLine IND POS(9);
 Switch IND POS(11);
 Cancel IND POS(12);
 JumpTop IND POS(17);
 JumpBottom IND POS(18);
 SubfileClear IND POS(30);
 SubfileDisplayControl IND POS(31);
 SubfileDisplay IND POS(32);
 SubfileMore IND POS(33);
 ShowSubfileOption IND POS(40);
 LockWindowEntry IND POS(48);
 HidePassword IND POS(49);
 WindowShowMessage IND POS(50);
END-DS;

DCL-DS MessageHandling_T TEMPLATE QUALIFIED;
 Length INT(10);
 Key CHAR(4);
 Error CHAR(128);
END-DS;

DCL-DS Catalogue_Entry_T TEMPLATE QUALIFIED;
 Description_Short CHAR(128);
 Description_Long CHAR(256);
 UserName CHAR(256);
 Password CHAR(256);
 URL CHAR(256);
 Remarks CHAR(1024);
 Stamp TIMESTAMP;
 LastUser CHAR(128);
END-DS;
