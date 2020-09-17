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

// Created by BRC on 13.02.2020 - 14.09.2020

// This program stores different login data in different catalogues encrypted by db2
//  crypto-services. Please use telnet over tls for secure communication :-)

// This program need database journal for commitment control and db2 crypto services!


/INCLUDE KEYSAFE/QRPGLEH,COPYRIGHT
/INCLUDE KEYSAFE/QRPGLEH,H_SPECS
CTL-OPT MAIN(Main);


DCL-F KEYSAFEDF WORKSTN INDDS(WSDS) EXTFILE('KEYSAFEDF') ALIAS USROPN
                 SFILE(KEYSAFEAS :AC_RecordNumber)
                 SFILE(KEYSAFEW2S :W2C_RecordNumber);


DCL-PR Main EXTPGM('KEYSAFERG') END-PR;


/INCLUDE KEYSAFE/QRPGLEH,KEYSAFE_H

/INCLUDE KEYSAFE/QRPGLECPY,SYSTEM
/INCLUDE KEYSAFE/QRPGLECPY,QUSCMDLN
/INCLUDE KEYSAFE/QRPGLECPY,QMHSNDPM


//#########################################################################
DCL-PROC Main;

 /INCLUDE KEYSAFE/QRPGLEH,SQLOPTIONS

 Reset This;
 *INLR = TRUE;

 system('STRCMTCTL LCKLVL(*CS) CMTSCOPE(*ACTGRP)');

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
           Exec SQL ROLLBACK;
       EndMon;

     Other;
       This.PictureControl = FM_END;

   EndSl;

 EndDo;

 Return;

On-Exit;

 system('ENDCMTCTL');

 If %Open(KEYSAFEDF);
   Close KEYSAFEDF;
 EndIf;

END-PROC;


//**************************************************************************
DCL-PROC loopFM_A;

 Exec SQL SAVEPOINT FM_A ON ROLLBACK RETAIN CURSORS;

 Clear KEYSAFEAC;
 Clear KEYSAFEAS;
 initFM_A();

 AC_Current_Row = 7;
 AC_Current_Column = 3;

 DoW ( This.PictureControl = FM_A );

   fetchRecordsFM_A();

   Write KEYSAFEAC;
   Write KEYSAFEAF;
   Write KEYSAFEZC;
   ExFmt KEYSAFEAC;

   clearMessages(PgmQueue :CallStack);

   Select;

     When WSDS.Exit;
       If checkForOpenCommits();
         This.PictureControl = FM_END;
       Else;
         initFM_A();
       EndIf;

     When WSDS.Refresh;
       initFM_A();

     When WSDS.NewEntry;
       createNewCatalogueEntry();
       initFM_A();

     When WSDS.CommandLine;
       promptCommandLine();
       initFM_A();

     When WSDS.Switch;
       If Not switchCatalogue();
         sendMessageToDisplay(MESSAGE_OPERATION_CANCELED :'' :PgmQueue :CallStack);
       EndIf;
       initFM_A();

     When WSDS.JumpTop;
       initFM_A();
       AC_Current_Cursor = 1;
       sendMessageToDisplay(STATUS_JUMP_TOP :AS_Option :PgmQueue :CallStack);

     When WSDS.JumpBottom;
       initFM_A();
       AC_Current_Cursor = MAX_RECORDS;
       sendMessageToDisplay(STATUS_JUMP_BOTTOM :AS_Option :PgmQueue :CallStack);

     Other;
       checkFM_A();
       initFM_A();

   EndSl;

 EndDo;

 Exec SQL RELEASE SAVEPOINT FM_A;

END-PROC;
//**************************************************************************
DCL-PROC initFM_A;
 DCL-PI *N IND END-PI;

 DCL-S Success IND INZ(TRUE);
 //-------------------------------------------------------------------------

 Reset AC_RecordNumber;

 If ( This.CatalogueName = '' );
   If Not setCatalogue();
     This.PictureControl = FM_END;
     Success = FALSE;
   EndIf;
 EndIf;

 EvalR AC_Device = %TrimR(PSDS.JobName);
 AC_Catalogue = This.CatalogueName;

 If Success;
   WSDS.SubfileClear = TRUE;
   WSDS.SubfileDisplayControl = TRUE;
   WSDS.SubfileDisplay = FALSE;
   WSDS.SubfileMore = FALSE;
   Write(E) KEYSAFEAC;
 EndIf;

 Return Success;

END-PROC;
//**************************************************************************
// This procedure reads the catalogue entries over the view to decrypt the
//  values with the encryption password
DCL-PROC fetchRecordsFM_A;

 DCL-S Success IND INZ(TRUE);
 DCL-S SearchDescriptionShort CHAR(60) INZ;
 DCL-S SearchRemarks CHAR(128) INZ;

 DCL-DS ResultDS QUALIFIED INZ;
  Link CHAR(32);
  Description_Short CHAR(30);
  Remarks CHAR(80);
 END-DS;

 DCL-DS SubfileDS QUALIFIED INZ;
  Color1 CHAR(1);
  Description_Short CHAR(30);
  Color2 CHAR(2);
  Remarks CHAR(80);
 END-DS;
 //-------------------------------------------------------------------------

 Clear KEYSAFEAS;
 Reset AC_RecordNumber;

 WSDS.SubfileClear = FALSE;
 WSDS.SubfileDisplayControl = TRUE;
 WSDS.SubfileDisplay = TRUE;
 WSDS.SubfileMore = TRUE;

 sendStatus(STATUS_PLEASE_WAIT);

 SearchDescriptionShort = '%' + %TrimR(AC_Entry_Find) + '%';
 SearchRemarks = '%' + %TrimR(AC_Remark_Find) + '%';

 Exec SQL DECLARE c_main_entry_reader SCROLL CURSOR FOR

           SELECT main_loop.link, main_loop.description_short,
                  LEFT(IFNULL(main_loop.remarks, ''), 80)
             FROM keysafe.main_loop
            WHERE main_loop.main_index = :This.CatalogueGUID
              AND UPPER(main_loop.description_short) LIKE RTRIM(UPPER(:SearchDescriptionShort))
              AND UPPER(IFNULL(main_loop.remarks, '')) LIKE RTRIM(UPPER(:SearchRemarks))
            ORDER BY main_loop.description_short;

 Exec SQL OPEN c_main_entry_reader;

 DoW ( This.Loop );

   Exec SQL FETCH NEXT FROM c_main_entry_reader INTO :ResultDS;

   If ( SQLCode = 100 ) Or ( AC_RecordNumber = MAX_RECORDS );
     Exec SQL CLOSE c_main_entry_reader;
     Leave;

   ElseIf ( SQLCode <> 100 ) And ( SQLCode <> 0 );
     Exec SQL GET DIAGNOSTICS CONDITION 1 :AS_Subfile_Line = MESSAGE_TEXT;
     Exec SQL CLOSE c_main_entry_reader;
     AC_RecordNumber += 1;
     AS_Record_Number = AC_RecordNumber;
     WSDS.ShowSubfileOption = FALSE;
     Write KEYSAFEAS;
     Leave;

   EndIf;

   SubfileDS.Color1 = COLOR_WHT;
   SubfileDS.Description_Short = ResultDS.Description_Short;
   SubfileDS.Color2 = COLOR_GRN;
   SubfileDS.Remarks = ResultDS.Remarks;

   AC_RecordNumber += 1;
   Clear AS_Option;
   AS_Subfile_Line = SubfileDS;
   AS_Record_Number = AC_RecordNumber;
   AS_Entry_GUID = ResultDS.Link;
   WSDS.ShowSubfileOption = TRUE;
   Write KEYSAFEAS;

 EndDo;

 If ( AC_RecordNumber = 0 ) And ( This.GlobalMessage = '' );
   AC_RecordNumber = 1;
   AC_Current_Row = 5;
   AC_Current_Column = 6;
   AS_Subfile_Line = COLOR_GRN + retrieveMessageText(MESSAGE_NO_RECORDS_FOUND);
   AS_Record_Number = AC_RecordNumber;
   WSDS.ShowSubfileOption = FALSE;
   Write KEYSAFEAS;

 ElseIf ( AC_RecordNumber = 0 ) And ( This.GlobalMessage <> '' );
   AC_RecordNumber = 1;
   AC_Current_Row = 5;
   AC_Current_Column = 6;
   AS_Subfile_Line = COLOR_WHT + This.GlobalMessage;
   AS_Record_Number = AC_RecordNumber;
   WSDS.ShowSubfileOption = FALSE;
   Write KEYSAFEAS;

 Else;
   If ( AC_Current_Cursor > 0 ) And ( AC_Current_Cursor <= AC_RecordNumber );
     AC_RecordNumber = AC_Current_Cursor;
   Else;
     AC_RecordNumber = 1;
   EndIf;

 EndIf;

END-PROC;
//**************************************************************************
DCL-PROC checkFM_A;

 DoW ( This.Loop );

   ReadC KEYSAFEAS;
   If %EoF;
     Leave;
   EndIf;

   Select;

     When ( AS_Option = '' );
       Iter;

     When ( AS_Option = '2' );
       editCatalogueEntry(AS_Entry_GUID);

     When ( AS_Option = '4' );
       deleteCatalogueEntry(AS_Entry_GUID);

     When ( AS_Option = '5' );
       viewCatalogueEntry(AS_Entry_GUID);

     Other;
       sendMessageToDisplay(MESSAGE_OPTION_NOT_EXIST :AS_Option :PgmQueue :CallStack);

   EndSl;

 EndDo;

END-PROC;


//**************************************************************************
// This procedure checks the password and set this value as the new
//  encryption password used for the selected catalogue
DCL-PROC setCatalogue;
 DCL-PI *N IND END-PI;

 DCL-S Success IND INZ(TRUE);
 DCL-S PasswordHint CHAR(60) INZ;
 //-------------------------------------------------------------------------

 WSDS.WindowShowMessage = FALSE;
 W0_Current_Row = 2;
 W0_Current_Column = 13;

 W0_Window_Title = retrieveMessageText(WINDOW_LOGIN);
 W0_Catalogue = This.CatalogueName;
 Clear W0_Password;

 DoW ( This.Loop );

   Write KEYSAFEW0;
   ExFmt KEYSAFEW0;

   Reset Success;
   WSDS.WindowShowMessage = FALSE;

   If WSDS.Exit;
     Clear KEYSAFEW0;
     Success = FALSE;
     If ( This.CatalogueName <> '' );
       This.PictureControl = FM_End;
     EndIf;
     Leave;

   ElseIf WSDS.SearchEntry;
     If ( W0_Current_Field = 'W0CATA' );
       W0_Catalogue = searchCatalogue();
       If ( W0_Catalogue <> '' );
         W0_Current_Row = 4;
         W0_Current_Column = 13;
       EndIf;
     Else;
       W0_Message = retrieveMessageText(MESSAGE_NO_PROMPT_AVAILABLE);
       WSDS.WindowShowMessage = TRUE;
     EndIf;
     Iter;

   ElseIf WSDS.NewEntry;
     W0_Catalogue = createNewCatalogue();
     Iter;

   ElseIf WSDS.Cancel;
     If ( This.CatalogueName = '' );
       Clear KEYSAFEW0;
       Success = FALSE;
       Leave;

     Else;
       W0_Message = retrieveMessageText(MESSAGE_CANCEL_NOT_ALLOWED);
       WSDS.WindowShowMessage = TRUE;
       Iter;

     EndIf;

   Else;

     Select;

       When ( W0_Catalogue = '' );
         W0_Current_Row = 2;
         W0_Current_Column = 13;
         W0_Message = retrieveMessageText(ERROR_CATALOGUE_NOT_FOUND);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W0_Password = '' );
         W0_Current_Row = 4;
         W0_Current_Column = 13;
         W0_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
         WSDS.WindowShowMessage = TRUE;
         Iter;
       
       Other;
         Clear W0_Foot_Line;
         Exec SQL SELECT '0' INTO :Success FROM keysafe.catalogues
                   WHERE catalogues.catalogue_name = :W0_Catalogue
                     AND catalogues.keytest IS NULL;

         If Not Success;

           If Not setCataloguePassword(W0_Catalogue);
             W0_Message = retrieveMessageText(ERROR_MISSING_PWD);
             WSDS.WindowShowMessage = TRUE;
             Iter;

           EndIf;

         Else;
           Exec SQL SET ENCRYPTION PASSWORD = :W0_Password;
           Clear W0_Password;

         EndIf;

         Exec SQL SELECT IFNULL(catalogues.catalogue_name, ''),
                         IFNULL(catalogues.guid, ''),
                         IFNULL(GETHINT(catalogues.keytest), ''),
                         CASE WHEN DECRYPT_CHAR(catalogues.keytest) = '1' THEN '1' ELSE '0' END
                    INTO :This.CatalogueName, :This.CatalogueGUID, :PasswordHint, :Success
                    FROM keysafe.catalogues
                   WHERE catalogues.catalogue_name = :W0_Catalogue;

         Success = Success And ( SQLCode = 0 );

         If Not Success And ( SQLCode <> 0 );
           W0_Current_Row = 2;
           W0_Current_Column = 13;
           Exec SQL GET DIAGNOSTICS CONDITION 1 :W0_Message = MESSAGE_TEXT;
           WSDS.WindowShowMessage = TRUE;
           If ( PasswordHint <> '' );
             EvalR W0_Foot_Line = %TrimR(PasswordHint);
           EndIf;
           Iter;

         ElseIf Not Success And ( SQLCode = 0 );
           W0_Current_Row = 4;
           W0_Current_Column = 13;
           W0_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
           WSDS.WindowShowMessage = TRUE;
           If ( PasswordHint <> '' );
             EvalR W0_Foot_Line = %TrimR(PasswordHint);
           EndIf;
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
// If the selected catalogue has no password this procedure will be called
//  to set a new password
DCL-PROC setCataloguePassword;
 DCL-PI *N IND;
  pCatalogueName CHAR(30) CONST;
 END-PI;

 DCL-S Success IND INZ(TRUE);
 //-------------------------------------------------------------------------

 Clear KEYSAFEW1;
 WSDS.WindowShowMessage = FALSE;
 W1_Window_Title = retrieveMessageText(WINDOW_SET_PWD);

 DoW ( This.Loop );

   Write KEYSAFEW1;
   ExFmt KEYSAFEW1;

   Reset Success;
   WSDS.WindowShowMessage = FALSE;

   If WSDS.Exit;
     Clear KEYSAFEW1;
     Success = FALSE;
     Leave;

   Else;

     Select;

       When ( W1_Password = '' );
         W1_Current_Row = 2;
         W1_Current_Column = 13;
         W1_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W1_Check_Password = '' );
         W1_Current_Row = 4;
         W1_Current_Column = 13;
         W1_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( %Len(%TrimR(W1_Password)) < 6 );
         W1_Current_Row = 2;
         W1_Current_Column = 13;
         W1_Message = retrieveMessageText(ERROR_PWD_TO_SHORT);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W1_Password <> W1_Check_Password );
         W1_Current_Row = 4;
         W1_Current_Column = 13;
         W1_Message = retrieveMessageText(ERROR_PWD_CHECK_NOT_MATCH);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       Other;
         Exec SQL SET ENCRYPTION PASSWORD = :W1_Password WITH HINT :W1_Password_Hint;

         Clear W1_Password;
         Clear W1_Check_Password;

         Exec SQL UPDATE keysafe.catalogues
                     SET catalogues.keytest = ENCRYPT_TDES('1')
                   WHERE catalogues.catalogue_name = :pCatalogueName
                     AND catalogues.keytest IS NULL WITH NC;

         Success = Success And ( SQLCode = 0 );

         If Not Success And ( SQLCode <> 0 );
           Exec SQL GET DIAGNOSTICS CONDITION 1 :W1_Message = MESSAGE_TEXT;
           WSDS.WindowShowMessage = TRUE;
           Iter;

         ElseIf Not Success And ( SQLCode = 0 );
           W1_Message = retrieveMessageText(ERROR_MISSING_PWD);
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
DCL-PROC searchCatalogue;
 DCL-PI *N CHAR(30) END-PI;

 DCL-S Catalogue_Name CHAR(32) INZ;
 DCL-S SearchString CHAR(64) INZ;
 //-------------------------------------------------------------------------

 Clear KEYSAFEW2C;

 W2C_Window_Title = retrieveMessageText(WINDOW_SEARCH_CATALOGUE);

 DoW ( This.Loop );

   Clear KEYSAFEW2S;
   Reset W2C_RecordNumber;

   WSDS.SubfileClear = TRUE;
   WSDS.SubfileDisplayControl = TRUE;
   WSDS.SubfileDisplay = FALSE;
   WSDS.SubfileMore = FALSE;
   Write(E) KEYSAFEW2C;

   WSDS.SubfileClear = FALSE;
   WSDS.SubfileDisplayControl = TRUE;
   WSDS.SubfileDisplay = TRUE;
   WSDS.SubfileMore = TRUE;

   SearchString = '%' + %TrimR(W2C_Search_Find) + '%';

   Exec SQL DECLARE c_catalogue_search_reader SCROLL CURSOR FOR

             SELECT IFNULL(catalogues.description, ''), catalogues.catalogue_name,
                    catalogues.guid
               FROM keysafe.catalogues
              WHERE UPPER(catalogues.catalogue_name) CONCAT UPPER(catalogues.description)
                    LIKE RTRIM(UPPER(:SearchString))
              ORDER BY catalogues.catalogue_name;

   Exec SQL OPEN c_catalogue_search_reader;

   DoW ( This.Loop );

     Exec SQL FETCH NEXT FROM c_catalogue_search_reader
               INTO :W2S_Subfile_Line, :W2S_Catalogue_Name, :W2S_GUID;

     If ( SQLCode = 100 ) Or ( W2C_RecordNumber = 9999 );
       Exec SQL CLOSE c_catalogue_search_reader;
       Leave;
     EndIf;

     W2C_RecordNumber += 1;
     W2S_RecordNumber = W2C_RecordNumber;
     WSDS.ShowSubfileOption = TRUE;
     Write KEYSAFEW2S;

   EndDo;

   If ( W2C_RecordNumber = 0 );
     W2C_RecordNumber = 1;
     W2S_RecordNumber = W2C_RecordNumber;
     W2S_Subfile_Line = retrieveMessageText(MESSAGE_NO_MATCHING_CATALOGUE_FOUND);
     WSDS.ShowSubfileOption = FALSE;
     Write KEYSAFEW2S;
   Else;
     W2C_RecordNumber = 1;
   EndIf;

   Write KEYSAFEW2C;
   ExFmt KEYSAFEW2C;

   ReadC KEYSAFEW2S;

   If Not %EoF();

    If ( W2S_Option = '' );
      Iter;

     ElseIf ( W2S_Option = '1' );
       Catalogue_Name = W2S_Catalogue_Name;
       Leave;

     ElseIf ( W2S_Option = '4' );
       If deleteCatalogue(W2S_Catalogue_Name :W2S_GUID);
         Leave;

       Else;
         Iter;

       EndIf;

     EndIf;

   EndIf;

   If WSDS.Exit Or WSDS.Cancel;
     Leave;

   ElseIf WSDS.Refresh;
     Iter;

   Else;
     Iter;

   EndIf;

 EndDo;

 Return Catalogue_Name;

END-PROC;


//**************************************************************************
DCL-PROC createNewCatalogue;
 DCL-PI *N CHAR(30) END-PI;

 DCL-S Success IND INZ(TRUE);
 //-------------------------------------------------------------------------

 Clear KEYSAFEW3;
 WSDS.WindowShowMessage = FALSE;
 W3_Window_Title = retrieveMessageText(WINDOW_CREATE_CATALOGUE);

 DoW ( This.Loop );

   Write KEYSAFEW3;
   ExFmt KEYSAFEW3;

   Reset Success;
   WSDS.WindowShowMessage = FALSE;

   If WSDS.Cancel;
     Clear KEYSAFEW3;
     Success = FALSE;
     Leave;

   Else;

     Select;

       When ( W3_Catalogue_Name = '' );
         W3_Current_Row = 2;
         W3_Current_Column = 15;
         W3_Message = retrieveMessageText(ERROR_CATALOGUE_NAME_MISSING);
         WSDS.WindowShowMessage = TRUE;
         Iter;
       
       When checkCatalogueName(W3_Catalogue_Name);
         W3_Current_Row = 2;
         W3_Current_Column = 15;
         W3_Message = retrieveMessageText(ERROR_CATALOGUE_EXIST);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W3_Description = '' );
         W3_Current_Row = 3;
         W3_Current_Column = 15;
         W3_Message = retrieveMessageText(ERROR_SHORT_DESCR_MISSING);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W3_Password = '' );
         W3_Current_Row = 4;
         W3_Current_Column = 15;
         W3_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W3_Check_Password = '' );
         W3_Current_Row = 5;
         W3_Current_Column = 15;
         W3_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( %Len(%TrimR(W3_Password)) < 6 );
         W3_Current_Row = 4;
         W3_Current_Column = 15;
         W3_Message = retrieveMessageText(ERROR_PWD_TO_SHORT);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       When ( W3_Password <> W3_Check_Password );
         W3_Current_Row = 5;
         W3_Current_Column = 15;
         W3_Message = retrieveMessageText(ERROR_PWD_CHECK_NOT_MATCH);
         WSDS.WindowShowMessage = TRUE;
         Iter;

       Other;
         Exec SQL SET ENCRYPTION PASSWORD = :W3_Password WITH HINT :W3_Password_Hint;

         Clear W3_Password;
         Clear W3_Check_Password;

         Exec SQL INSERT INTO keysafe.catalogues
                  (catalogues.catalogue_name, catalogues.guid,
                   catalogues.description, catalogues.keytest)
                  VALUES(:W3_Catalogue_Name, KEYSAFE.GENERATE_GUID(),
                         RTRIM(:W3_Description), ENCRYPT_TDES('1')) WITH NC;

         Success = Success And ( SQLCode = 0 );

         If Not Success And ( SQLCode <> 0 );
           Exec SQL GET DIAGNOSTICS CONDITION 1 :W3_Message = MESSAGE_TEXT;
           WSDS.WindowShowMessage = TRUE;
           Iter;

         ElseIf Not Success And ( SQLCode = 0 );
           W3_Message = retrieveMessageText(ERROR_MISSING_PWD);
           WSDS.WindowShowMessage = TRUE;
           Iter;

         ElseIf Success;
           Leave;

         EndIf;

     EndSl;

   EndIf;

 EndDo;

 Return W3_Catalogue_Name;

END-PROC;


//**************************************************************************
DCL-PROC switchCatalogue;
 DCL-PI *N IND END-PI;

 DCL-S Success IND INZ(TRUE);
 //-------------------------------------------------------------------------

 If checkForOpenCommits();
   Success = setCatalogue();
 Else;
   Success = FALSE;
 EndIf;

 Return Success;

END-PROC;


//**************************************************************************
DCL-PROC deleteCatalogue;
 DCL-PI *N IND;
  pCatalogueName CHAR(32) CONST;
  pGUID CHAR(32) CONST;
 END-PI;

 DCL-S Success IND INZ(TRUE);
 //-------------------------------------------------------------------------

 Clear KEYSAFEW7;
 WSDS.WindowShowMessage = FALSE;
 W7_Window_Title = retrieveMessageText(WINDOW_DELETE_CATALOGUE);
 W7_Catalogue = pCatalogueName;
 W7_Current_Row = 4;
 W7_Current_Column = 13;

 DoW ( This.Loop );

   Write KEYSAFEW7;
   ExFmt KEYSAFEW7;

   W7_Current_Row -= 1;
   W7_Current_Column -= 3;

   Reset Success;
   WSDS.WindowShowMessage = FALSE;

   If WSDS.Cancel;
     Success = FALSE;
     Leave;

   Else;

     Select;
     
       When Not checkCatalogueName(pCatalogueName);
         W7_Current_Row = 4;
         W7_Current_Column = 13;
         W7_Message = retrieveMessageText(ERROR_CATALOGUE_NOT_EXIST);
         WSDS.WindowShowMessage = TRUE;
         Iter;
       
       When ( W7_Password = '' );
         W7_Current_Row = 4;
         W7_Current_Column = 13;
         W7_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
         WSDS.WindowShowMessage = TRUE;

       When ( W7_Check_Password = '' );
         W7_Current_Row = 5;
         W7_Current_Column = 13;
         W7_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
         WSDS.WindowShowMessage = TRUE;

       When ( W7_Password <> W7_Check_Password );
         W7_Current_Row = 4;
         W7_Current_Column = 13;
         W7_Message = retrieveMessageText(ERROR_PWD_CHECK_NOT_MATCH);
         WSDS.WindowShowMessage = TRUE;

       Other;
         Exec SQL SET ENCRYPTION PASSWORD = :W7_Password;

         Clear W7_Password;
         Clear W7_Check_Password;

         Exec SQL SELECT CASE WHEN DECRYPT_CHAR(catalogues.keytest) = '1' THEN '1'
                              ELSE '0' END INTO :Success
                    FROM keysafe.catalogues
                   WHERE catalogues.guid = :pGUID;

         If ( SQLCode <> 0 ) Or Not Success;
           W7_Current_Row = 4;
           W7_Current_Column = 13;
           W7_Message = retrieveMessageText(ERROR_PWD_EMPTY_WRONG);
           WSDS.WindowShowMessage = TRUE;

         Else;

           Exec SQL DELETE FROM keysafe.main WHERE main.main_index = :pGUID WITH NC;

           If ( SQLCode = 0 ) Or ( SQLCode = 100 );
             Exec SQL DELETE FROM keysafe.catalogues WHERE catalogues.guid = :pGUID WITH NC;
             If ( SQLCode = 0 );
               Leave;

             Else;
               Exec SQL GET DIAGNOSTICS CONDITION 1 :W7_Message = MESSAGE_TEXT;
               WSDS.WindowShowMessage = TRUE;
               Iter;

             EndIf;

           Else;
             Exec SQL GET DIAGNOSTICS CONDITION 1 :W7_Message = MESSAGE_TEXT;
             WSDS.WindowShowMessage = TRUE;
             Iter;

           EndIf;

         EndIf;

     EndSl;

   EndIf;

 EndDo;

 Return Success;

END-PROC;


//**************************************************************************
DCL-PROC createNewCatalogueEntry;

 DCL-S Success IND INZ(TRUE);
 DCL-S GUID CHAR(32) INZ;
 //-------------------------------------------------------------------------

 Clear KEYSAFEW6;
 WSDS.LockWindowEntry = FALSE;
 WSDS.HidePassword = FALSE;
 WSDS.WindowShowMessage = FALSE;
 W6_Window_Title = %TrimR(retrieveMessageText(WINDOW_CREATE_ENTRY)) + ' (' +
                   %TrimR(This.CatalogueName) + ')';

 DoW ( This.Loop );

   Write KEYSAFEW6;
   ExFmt KEYSAFEW6;

   W6_Current_Row -= 1;
   W6_Current_Column -= 3;

   If WSDS.Exit;
     Leave;

   ElseIf WSDS.Refresh;
     Iter;

   ElseIf WSDS.CommandLine;
     promptCommandLine();
     Iter;

   ElseIf WSDS.Switch;
     If WSDS.HidePassword = TRUE;
       WSDS.HidePassword = FALSE;
     Else;
       WSDS.HidePassword = TRUE;
     EndIf;
     Iter;

   ElseIf WSDS.Cancel;
     Leave;

   Else;
     If ( W6_Description_Short = '' );
       W6_Current_Row = 3;
       W6_Current_Column = 2;
       WSDS.WindowShowMessage = TRUE;
       W6_Message = retrieveMessageText(ERROR_SHORT_DESCR_MISSING);
       Success = FALSE;

     Else;
       Reset Success;

     EndIf;

     If Not Success;
       Iter;
     EndIf;

     Exec SQL SELECT link INTO :GUID FROM FINAL TABLE
              (
               INSERT INTO keysafe.main
                (main.main_index, main.link)
                 VALUES(:This.CatalogueGUID, KEYSAFE.GENERATE_GUID())
               ) WITH CS;

     If ( SQLCode = 0 );
       Exec SQL INSERT INTO keysafe.lines
                (lines.link, lines.description_short, lines.description_long, lines.username,
                 lines.user_password, lines.url, lines.remarks)
                 VALUES(:GUID, ENCRYPT_TDES(RTRIM(:W6_Description_Short)),
                        ENCRYPT_TDES(NULLIF(RTRIM(:W6_Description_Long), '')),
                        ENCRYPT_TDES(NULLIF(RTRIM(:W6_UserName), '')),
                        ENCRYPT_TDES(NULLIF(RTRIM(:W6_Password), '')),
                        ENCRYPT_TDES(NULLIF(RTRIM(:W6_URL), '')),
                        ENCRYPT_TDES(NULLIF(RTRIM(:W6_Remarks), '')))
                WITH CS;
     EndIf;

     If ( SQLCode <> 0 );
       Exec SQL GET DIAGNOSTICS CONDITION 1 :W6_Message = MESSAGE_TEXT;
       WSDS.WindowShowMessage = TRUE;

     Else;
       Leave;

     EndIf;

   EndIf;

 EndDo;

END-PROC;


//**************************************************************************
DCL-PROC editCatalogueEntry;
 DCL-PI *N;
  pGUID CHAR(32) CONST;
 END-PI;

 DCL-S Success IND INZ(TRUE);
 DCL-DS EntryDS LIKEDS(Catalogue_Entry_T) INZ;
 //-------------------------------------------------------------------------

 Clear KEYSAFEW6;
 WSDS.LockWindowEntry = FALSE;
 WSDS.HidePassword = TRUE;
 WSDS.WindowShowMessage = FALSE;
 W6_Window_Title = %TrimR(retrieveMessageText(WINDOW_CHANGE_ENTRY)) + ' (' +
                   %TrimR(This.CatalogueName) + ')';

 If Not getCatalogueEntry(pGUID :EntryDS);
   Return;
 Else;
   loadCatalogieEntryToScreen(EntryDS);
 EndIf;

 DoW ( This.Loop );

   Write KEYSAFEW6;
   ExFmt KEYSAFEW6;

   W6_Current_Row -= 1;
   W6_Current_Column -= 3;

   If WSDS.Exit;
     Leave;

   ElseIf WSDS.Refresh;
     loadCatalogieEntryToScreen(EntryDS);
     Iter;

   ElseIf WSDS.CommandLine;
     promptCommandLine();
     Iter;

   ElseIf WSDS.Switch;
     If WSDS.HidePassword = TRUE;
       WSDS.HidePassword = FALSE;
     Else;
       WSDS.HidePassword = TRUE;
     EndIf;
     Iter;

   ElseIf WSDS.Cancel;
     Leave;

   Else;
     If ( W6_Description_Short = '' );
       W6_Current_Row = 3;
       W6_Current_Column = 2;
       WSDS.WindowShowMessage = TRUE;
       W6_Message = retrieveMessageText(ERROR_SHORT_DESCR_MISSING);
       Success = FALSE;

     Else;
       Reset Success;

     EndIf;

     If Not Success;
       Iter;
     EndIf;

     If ( W6_Description_Short <> EntryDS.Description_Short )
       Or ( W6_Description_Long <> EntryDS.Description_Long )
       Or ( W6_UserName <> EntryDS.UserName )
       Or ( W6_Password <> EntryDS.Password )
       Or ( W6_URL <> EntryDS.URL )
       Or ( W6_Remarks <> EntryDS.Remarks );
       Exec SQL UPDATE keysafe.lines
                   SET lines.description_short =
                        ENCRYPT_TDES(NULLIF(RTRIM(:W6_Description_Short), '')),
                       lines.description_long =
                        ENCRYPT_TDES(NULLIF(RTRIM(:W6_Description_Long), '')),
                       lines.username = ENCRYPT_TDES(NULLIF(RTRIM(:W6_UserName), '')),
                       lines.user_password = ENCRYPT_TDES(NULLIF(RTRIM(:W6_Password), '')),
                       lines.url = ENCRYPT_TDES(NULLIF(RTRIM(:W6_URL), '')),
                       lines.remarks = ENCRYPT_TDES(NULLIF(RTRIM(:W6_Remarks), '')),
                       lines.stamp = CURRENT_TIMESTAMP,
                       lines.last_user = USER
                 WHERE lines.link = :pGUID
                  WITH CS;

       If ( SQLCode <> 0 );
         Exec SQL GET DIAGNOSTICS CONDITION 1 :W6_Message = MESSAGE_TEXT;
         WSDS.WindowShowMessage = TRUE;
         Iter;

       Else;
         Leave;

       EndIf;

     Else;
       Leave;

     EndIf;

   EndIf;

 EndDo;

END-PROC;


//**************************************************************************
DCL-PROC deleteCatalogueEntry;
 DCL-PI *N;
  pGUID CHAR(32) CONST;
 END-PI;

 DCL-S ErrorMessage CHAR(128) INZ;
 //-------------------------------------------------------------------------

 W4_Window_Row = AC_Current_Row - 2;
 W4_Window_Column = AC_Current_Column + 2;

 Write KEYSAFEW4;
 ExFmt KEYSAFEW4;

 If Not WSDS.Cancel;

   Exec SQL DELETE FROM keysafe.main
             WHERE main.main_index = :This.CatalogueGUID AND main.link = :pGUID
              WITH CS;

   If ( SQLCode <> 0 );
     Exec SQL GET DIAGNOSTICS CONDITION 1 :ErrorMessage = MESSAGE_TEXT;
     sendMessageToDisplay(ERROR_INDIVIDUAL :ErrorMessage :PgmQueue :CallStack);
   EndIf;

 Else;
   sendMessageToDisplay(MESSAGE_OPERATION_CANCELED :'' :PgmQueue :CallStack);

 EndIf;

END-PROC;


//**************************************************************************
DCL-PROC viewCatalogueEntry;
 DCL-PI *N;
  pGUID CHAR(32) CONST;
 END-PI;

 DCL-S Success IND INZ(TRUE);
 DCL-DS EntryDS LIKEDS(Catalogue_Entry_T) INZ;
 //-------------------------------------------------------------------------

 Clear KEYSAFEW6;
 WSDS.LockWindowEntry = TRUE;
 WSDS.HidePassword = TRUE;
 WSDS.WindowShowMessage = FALSE;
 W6_Window_Title = %TrimR(retrieveMessageText(WINDOW_VIEW_ENTRY)) + ' (' +
                   %TrimR(This.CatalogueName) + ')';

 If Not getCatalogueEntry(pGUID :EntryDS);
   Return;
 Else;
   loadCatalogieEntryToScreen(EntryDS);
 EndIf;

 DoW ( This.Loop );

   Write KEYSAFEW6;
   ExFmt KEYSAFEW6;

   W6_Current_Row -= 1;
   W6_Current_Column -= 3;

   If WSDS.Exit;
     Leave;

   ElseIf WSDS.Refresh;
     loadCatalogieEntryToScreen(EntryDS);
     Iter;

   ElseIf WSDS.CommandLine;
     promptCommandLine();
     Iter;

   ElseIf WSDS.Switch;
     If WSDS.HidePassword = TRUE;
       WSDS.HidePassword = FALSE;
     Else;
       WSDS.HidePassword = TRUE;
     EndIf;
     Iter;

   ElseIf WSDS.Cancel;
     Leave;

   Else;
     Leave;

   EndIf;

 EndDo;

END-PROC;


//**************************************************************************
// This procedure read the single entry record with the decryption view
DCL-PROC getCatalogueEntry;
 DCL-PI *N IND;
  pGUID CHAR(32) CONST;
  pEntryDS LIKEDS(Catalogue_Entry_T);
 END-PI;
 //-------------------------------------------------------------------------

 Exec SQL SELECT IFNULL(lines_view.description_short, ''),
                 IFNULL(lines_view.description_long, ''),
                 IFNULL(lines_view.username, ''), IFNULL(lines_view.user_password, ''),
                 IFNULL(lines_view.url, ''), IFNULL(lines_view.remarks, ''),
                 lines_view.stamp, lines_view.last_user
            INTO :pEntryDS
            FROM keysafe.lines_view
           WHERE lines_view.link = :pGUID;

 Return ( SQLCode = 0 );

END-PROC;


//**************************************************************************
DCL-PROC loadCatalogieEntryToScreen;
 DCL-PI *N;
  pEntryDS LIKEDS(Catalogue_Entry_T) CONST;
 END-PI;
 //-------------------------------------------------------------------------

 W6_Description_Short = pEntryDS.Description_Short;
 W6_Description_Long = pEntryDS.Description_Long;
 W6_UserName = pEntryDS.UserName;
 W6_Password = pEntryDS.Password;
 W6_URL = pEntryDS.URL;
 W6_Remarks = pEntryDS.Remarks;
 EvalR W6_Foot_Line = %Char(%Date(pEntryDS.Stamp) :*EUR.) + '-' +
                      %Char(%Time(pEntryDS.Stamp) :*HMS:) + '-' +
                      %TrimR(pEntryDS.LastUser);

END-PROC;


//**************************************************************************
DCL-PROC checkCatalogueName;
 DCL-PI *N IND;
  pCatalogueName CHAR(30) CONST;
 END-PI;

 DCL-S RecordFound IND INZ(FALSE);
 //-------------------------------------------------------------------------

 Exec SQL SELECT '1' INTO :RecordFound
            FROM keysafe.catalogues
           WHERE catalogue_name = :pCatalogueName;
           
 RecordFound = RecordFound And ( SQLCode = 0 );
 
 Return RecordFound;

END-PROC;


//**************************************************************************
DCL-PROC checkForOpenCommits;
 DCL-PI *N IND END-PI;

 DCL-S ReturnParm IND INZ(TRUE);
 DCL-S ActiveTransactions INT(10) INZ;
 //-------------------------------------------------------------------------

 Exec SQL GET DIAGNOSTICS :ActiveTransactions = TRANSACTION_ACTIVE;

 If ( SQLCode = 0 ) And ( ActiveTransactions > 0 );

   Write KEYSAFEW5;
   ExFmt KEYSAFEW5;

   If ( WSDS.Exit );
     Exec SQL ROLLBACK;
     ReturnParm = TRUE;

   ElseIf ( WSDS.Cancel );
     ReturnParm = FALSE;

   Else;
     Exec SQL COMMIT;
     ReturnParm = TRUE;

   EndIf;

 EndIf;

 Return ReturnParm;

END-PROC;


//**************************************************************************
DCL-PROC sendMessageToDisplay;
 DCL-PI *N;
  pMessageID CHAR(7) CONST;
  pMessage CHAR(256) CONST;
  pProgramQueue CHAR(10) CONST;
  pCallStack INT(10) CONST;
 END-PI;

 DCL-DS MessageDS LIKEDS(MessageHandling_T) INZ;
 //-------------------------------------------------------------------------

 MessageDS.Length = %Len(%TrimR(pMessage));

 If ( pMessageID <> '' );
   sendProgramMessage(pMessageID :KEYMSGF :pMessage :MessageDS.Length :'*INFO'
                      :pProgramQueue :pCallStack :MessageDS.Key :MessageDS.Error);
 EndIf;

END-PROC;


//**************************************************************************
DCL-PROC sendStatus;
 DCL-PI *N;
  pMessageID CHAR(7) CONST;
  pMessage CHAR(256) CONST OPTIONS(*NOPASS);
 END-PI;

 DCL-DS MessageDS LIKEDS(MessageHandling_T) INZ;

 DCL-S Message CHAR(256) INZ;
 //-------------------------------------------------------------------------

 If ( %Parms() = 2 );
   Message = pMessage;
 EndIf;

 MessageDS.Length = %Len(%TrimR(Message));

 If ( pMessageID <> '' );
   sendProgramMessage(pMessageID :KEYMSGF :Message :MessageDS.Length
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

 /INCLUDE KEYSAFE/QRPGLECPY,QMHRMVPM

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

 /INCLUDE KEYSAFE/QRPGLECPY,QMHRTVM

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
