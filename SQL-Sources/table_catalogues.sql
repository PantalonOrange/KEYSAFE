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

CREATE OR REPLACE TABLE KEYSAFE.CATALOGUES
( 
  CATALOGUE_NAME FOR COLUMN CAT_NAME CHAR(30) DEFAULT 'DEFAULT',
  GUID CHAR(32) DEFAULT NULL,
  DESCRIPTION FOR COLUMN DES VARCHAR(128) DEFAULT NULL,
  KEYTEST VARCHAR(24) FOR BIT DATA DEFAULT NULL IMPLICITLY HIDDEN,
  CONSTRAINT KEYSAFE.CATALOGUE_PRIMARY_KEY PRIMARY KEY(GUID)
) RCDFMT CAT00; 
  
ALTER TABLE KEYSAFE.CATALOGUES ADD CONSTRAINT KEYSAFE.CATALOGUE_UNIQUE_KEY UNIQUE(CATALOGUE_NAME); 
  
LABEL ON TABLE KEYSAFE.CATALOGUES IS 'Secure key store - catalogues' ; 
  
LABEL ON COLUMN KEYSAFE.CATALOGUES 
(
  CATALOGUE_NAME IS 'Catalogue           Name', 
  GUID IS 'Link                Guid', 
  DESCRIPTION IS 'Description', 
  KEYTEST IS 'Key                 Test'
); 
  
LABEL ON COLUMN KEYSAFE.CATALOGUES 
(
  CATALOGUE_NAME TEXT IS 'Catalogue name', 
  GUID TEXT IS 'Link to target catalogue', 
  DESCRIPTION TEXT IS 'Description', 
  KEYTEST TEXT IS 'Key test'
); 
  