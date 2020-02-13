-- Copyright (c) 2020 Christian Brunner
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

CREATE OR REPLACE VIEW KEYSAFE.MAIN_LOOP (DESCRIPTION_SHORT FOR COLUMN DES_SHORT, REMARKS) AS 

WITH MAIN_LOOP (DESCRIPTION_SHORT, REMARKS) AS 
(SELECT DECRYPT_CHAR(LN.DESCRIPTION_SHORT), DECRYPT_CHAR(LN.REMARKS) 
   FROM KEYSAFE.MAIN MN JOIN KEYSAFE.LINES LN ON (LN.LINK = MN.LINK)) 

SELECT DESCRIPTION_SHORT, REMARKS FROM MAIN_LOOP   

RCDFMT RDM00; 
  
LABEL ON TABLE KEYSAFE.MAIN_LOOP IS 'Secure key store - read main loop'; 
