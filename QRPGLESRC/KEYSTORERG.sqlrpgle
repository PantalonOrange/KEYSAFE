**FREE
// Copyright (c) 2020 Christian Brunner
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Created by BRC on 13.02.2020

// This program stores different login datas in different catalogues encrypted by db2
//  crypto-services

// CAUTION: ALPHA-VERSION

// TO-DOs:
//  + Everything


/INCLUDE QRPGLECPY,H_SPECS
CTL-OPT MAIN(Main);


DCL-F KEYSAFEDF WORKSTN INDDS(WSDS) EXTFILE('KEYSAFEDF') ALIAS
                 SFILE(KEYSAFEAS :RecordNumber) USROPN;


DCL-PR Main EXTPGM('KEYSAFERG') END-PR;


/INCLUDE QRPGLECPY,SYSTEM
/INCLUDE QRPGLECPY,QMHSNDPM

/INCLUDE QRPGLECPY,BOOLIC
/INCLUDE QRPGLECPY,HEX_COLORS

/INCLUDE QRPGLECPY,KEYSAFE_H
/INCLUDE QRPGLECPY,PSDS


//#########################################################################
DCL-PROC Main;

 /INCLUDE QRPGLECPY,SQLOPTIONS

 Reset This;
 *INLR = TRUE;

 If Not %Open(KEYSAFEDF);
   Open KEYSAFEDF;
 EndIf;

 DoU ( This.PictureControl = FM_END );

   Select;

     When ( This.PictureControl = FM_A );
       Monitor;
         loopFM_A();
         On-Error;
           This.PictureControl = FM_END;
           sendJobLog(PSDS.MessageID + ':' + PSDS.MessageData);
       EndMon;

     Other;
       This.PictureControl = FM_END;

   EndSl;

 EndDo;

 Return;

On-Exit;
 If %Open(KEYSAFEDF);
   Close KEYSAFEDF;
 EndIf;

END-PROC;


//**************************************************************************
DCL-PROC loopFM_A;

 /INCLUDE QRPGLECPY,QUSCMDLN

 DCL-S Success IND INZ(TRUE);


 DCL-DS FMA LIKEREC(KEYSAFEAC :*ALL) INZ;
 //-------------------------------------------------------------------------

 Success = initFM_A();

 fetchRecordsFM_A();

 DoW ( This.PictureControl = FM_A );

   AC_Catalogue = 'xxxx';

   Write KEYSAFEAF;
   Write KEYSAFEAC;
   ExFmt KEYSAFEAC;

   clearMessages(PgmQueue :CallStack);

   Select;

     When WSDS.Exit;
       This.PictureControl = FM_END;

     When WSDS.Refresh;
       fetchRecordsFM_A();

     When WSDS.NewRecord;

     When WSDS.CommandLine;
       promptCommandLine();

     Other;
       fetchRecordsFM_A();

   EndSl;

 EndDo;


END-PROC;
//**************************************************************************
DCL-PROC initFM_A;
 DCL-PI *N IND END-PI;

 DCL-S Success IND INZ(TRUE);
 //-------------------------------------------------------------------------

 Reset RecordNumber;
 Clear KEYSAFEAC;
 Clear KEYSAFEAS;

 AC_Device = PSDS.JobName;
 
 Success = setCatalogue();

 Return Success;

END-PROC;
//**************************************************************************
DCL-PROC fetchRecordsFM_A;

 DCL-S Success IND INZ(TRUE);

 DCL-DS SubfileDS QUALIFIED INZ;
   Color1 CHAR(1);
   Sender CHAR(40);
   Color2 CHAR(3);
   SendDate CHAR(25);
   Color3 CHAR(3);
   Subject CHAR(50);
 END-DS;
 //-------------------------------------------------------------------------

 Reset RecordNumber;

 WSDS.SubfileClear = TRUE;
 WSDS.SubfileDisplayControl = TRUE;
 WSDS.SubfileDisplay = FALSE;
 WSDS.SubfileMore = FALSE;
 Write(E) KEYSAFEAC;

 WSDS.SubfileClear = FALSE;
 WSDS.SubfileDisplayControl = TRUE;
 WSDS.SubfileDisplay = TRUE;
 WSDS.SubfileMore = TRUE;

 If ( This.RecordsFound > 0 );

   RecordNumber += 1;
   AS_Subfile_Line = SubfileDS;
   AS_Record_Number = RecordNumber;
   WSDS.ShowSubfileOption = TRUE;
   Write KEYSAFEAS;

   If ( AC_Current_Cursor > 0 ) And ( AC_Current_Cursor <= RecordNumber );
     RecordNumber = AC_Current_Cursor;
   Else;
     RecordNumber = 1;
   EndIf;

 ElseIf ( This.RecordsFound = 0 );
   RecordNumber = 1;
   AS_Subfile_Line = retrieveMessageText('M000000');
   AS_Record_Number = RecordNumber;
   WSDS.ShowSubfileOption = FALSE;
   Write KEYSAFEAS;

 Else;
   RecordNumber = 1;
   AS_Subfile_Line = COLOR_BLU + This.GlobalMessage;
   AS_Record_Number = RecordNumber;
   WSDS.ShowSubfileOption = FALSE;
   Write KEYSAFEAS;

 EndIf;

END-PROC;

//**************************************************************************
DCL-PROC setCatalogue;
 DCL-PI *N IND END-PI;

 DCL-S Success IND INZ(TRUE);
 //-------------------------------------------------------------------------

 WSDS.WindowErrorCatalogue = FALSE;
 WSDS.WindowShowMessage = FALSE;
 W0_Window_Title = retrieveMessageText('C000000');
 Clear W0_Catalogue;
 Clear W0_Password;

 DoW ( This.Loop );

   Write KEYSAFEW0;
   ExFmt KEYSAFEW0;

   Reset Success;
   WSDS.WindowErrorCatalogue = FALSE;
   WSDS.WindowShowMessage = FALSE;

   If WSDS.Exit;
     Clear KEYSAFEW0;
     This.PictureControl = FM_END;
     Success = FALSE;
     Leave;
   
   ElseIf WSDS.NewRecord;
     //createNewCatalogue();
   
   ElseIf WSDS.Cancel;
     Clear KEYSAFEW0;
     Success = TRUE;
     Leave;

   Else;

     Select;

       When ( W0_Catalogue = '' );
         W0_Current_Row = 2;
         W0_Current_Column = 13;
         WSDS.WindowErrorCatalogue = TRUE;
         W0_Message = retrieveMessageText('E000000');
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W0_Password = '' );
         W0_Current_Row = 4;
         W0_Current_Column = 12;
         W0_Message = retrieveMessageText('E000001');
         WSDS.WindowShowMessage = TRUE;
         Iter;

       Other;
         Exec SQL SELECT '0' INTO :Success FROM KEYSAFE.CATALOGUES
                   WHERE CATALOGUE_NAME = :W0_Catalogue AND KEYTEST IS NULL;
         If Not Success;
           Exec SQL SET ENCRYPTION PASSWORD = :W0_Password;
           Exec SQL UPDATE KEYSAFE.CATALOGUES SET KEYTEST = ENCRYPT('1')
                     WHERE CATALOGUE_NAME = :W0_Catalogue AND KEYTEST IS NULL;
         EndIf;

         Exec SQL SET ENCRYPTION PASSWORD = :W0_Password;

         Exec SQL SELECT CASE WHEN DECRYPT_CHAR(KEYTEST) = '1' THEN '1'
                              ELSE '0' END INTO :Success
                    FROM KEYSAFE.CATALOGUES
                   WHERE CATALOGUE_NAME = :W0_Catalogue;
         Success = Success And ( SQLCode = 0 );
         If Not Success And ( SQLCode <> 0 );
           Exec SQL GET DIAGNOSTICS CONDITION 1 :W0_Message = MESSAGE_TEXT;
           WSDS.WindowShowMessage = TRUE;
           Iter;
         ElseIf Not Success And ( SQLCode = 0 );
           W0_Message = retrieveMessageText('E000001');
           WSDS.WindowShowMessage = TRUE;
           Iter;
         ElseIf Success;
           Leave;
         EndIf;

     EndSl;

   EndIf;

 EndDo;

 Return Success;

END-PROC;


//**************************************************************************
DCL-PROC sendStatus;
 DCL-PI *N;
   pMessage CHAR(256) CONST;
 END-PI;

 DCL-DS MessageDS LIKEDS(MessageHandling_T) INZ;
 //-------------------------------------------------------------------------

 MessageDS.Length = %Len(%TrimR(pMessage));
 If ( MessageDS.Length >= 0 );
   sendProgramMessage('CPF9897' :CPFMSG :pMessage :MessageDS.Length
                      :'*STATUS' :'*EXT' :0 :MessageDS.Key :MessageDS.Error);
 EndIf;

END-PROC;


//**************************************************************************
DCL-PROC sendJobLog;
 DCL-PI *N;
   pMessage CHAR(256) CONST;
 END-PI;

 DCL-DS MessageDS LIKEDS(MessageHandling_T) INZ;
 //-------------------------------------------------------------------------

 MessageDS.Length = %Len(%TrimR(pMessage));
 If ( MessageDS.Length >= 0 );
   sendProgramMessage('CPF9897' :CPFMSG :pMessage :MessageDS.Length
                      :'*DIAG' :'*PGMBDY' :1 :MessageDS.Key :MessageDS.Error);
 EndIf;

END-PROC;


//**************************************************************************
DCL-PROC clearMessages;
 DCL-PI *N;
   pMessageProgramQueue CHAR(10) CONST;
   pMessageCallStack INT(10) CONST;
 END-PI;

 /INCLUDE QRPGLECPY,QMHRMVPM

 DCL-S Error CHAR(128) INZ;
 //-------------------------------------------------------------------------

 removeProgramMessage(pMessageProgramQueue :pMessageCallStack :'' :'*ALL' :Error);

END-PROC;


//**************************************************************************
DCL-PROC retrieveMessageText;
 DCL-PI *N CHAR(256);
   pMessageID CHAR(7) CONST;
   pMessageData CHAR(16) CONST OPTIONS(*NOPASS);
 END-PI;

 /INCLUDE QRPGLECPY,QMHRTVM

 DCL-C KEYMSGF 'KEYMSGF   *LIBL';

 DCL-S MessageData CHAR(16) INZ;
 DCL-S Error CHAR(128) INZ;
 DCL-DS RTVM0100 LIKEDS(RTVM0100_T) INZ;
 //-------------------------------------------------------------------------

 If ( %Parms() = 1 );
   Clear MessageData;
 Else;
   MessageData = pMessageData;
 EndIf;

 retrieveMessageData(RTVM0100 :%Size(RTVM0100) :'RTVM0100' :pMessageID :KEYMSGF :MessageData
                     :%Len(%TrimR(MessageData)) :'*YES' :'*NO' :Error);

 If ( RTVM0100.BytesMessageReturn > 0 );
   RTVM0100.MessageAndHelp = %SubSt(RTVM0100.MessageAndHelp :1 :RTVM0100.BytesMessageReturn);
 Else;
   Clear RTVM0100;
 EndIf;

 Return %SubSt(RTVM0100.MessageAndHelp :1 :256);

END-PROC;
