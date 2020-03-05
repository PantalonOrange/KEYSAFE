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

CREATE OR REPLACE TABLE KEYSAFE.MAIN
(
  MAIN_INDEX CHAR(32) DEFAULT NULL,
  LINK CHAR(32) DEFAULT NULL,
  CONSTRAINT KEYSAFE.MAIN_PRIMARY_KEY PRIMARY KEY(LINK)
) RCDFMT MAIN00;

ALTER TABLE KEYSAFE.MAIN ADD CONSTRAINT KEYSAFE.MAIN_UNIQUE_KEY UNIQUE(MAIN_INDEX, LINK);

ALTER TABLE KEYSAFE.MAIN
 ADD CONSTRAINT KEYSAFE.CATALOGUE_MAIN_LINK FOREIGN KEY(MAIN_INDEX)
 REFERENCES KEYSAFE.CATALOGUES (GUID)
 ON DELETE NO ACTION ON UPDATE NO ACTION;

LABEL ON TABLE KEYSAFE.MAIN IS 'Secure key store - main' ;

LABEL ON COLUMN KEYSAFE.MAIN
(
  MAIN_INDEX IS 'Index' ,
  LINK IS 'Link '
);

LABEL ON COLUMN KEYSAFE.MAIN
(
  MAIN_INDEX TEXT IS 'Mainindex' ,
  LINK TEXT IS 'Link'
);
