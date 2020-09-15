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

// Created by BRC on 15.09.2020


CTL-OPT NOMAIN;


DCL-PR genGUID CHAR(16) END-PR;


//**************************************************************************
DCL-PROC genGUID EXPORT;
 DCL-PI *N CHAR(16) END-PI;

 DCL-DS GuidDS QUALIFIED;
  BytesProv UNS(10) INZ(%Size(GuidDS));
  BytesAvail UNS(10);
  Temp CHAR(8) INZ(*ALLX'00');
  UUID CHAR(16);
 END-DS;

 DCL-PR genUUID EXTPROC('_GENUUID');
  Template POINTER VALUE;
 END-PR;
 //-------------------------------------------------------------------------

 genUUID(%Addr(GuidDS));

 Return GuidDS.UUID;

END-PROC;
