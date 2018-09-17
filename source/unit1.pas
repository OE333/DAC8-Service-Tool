{
MIT License

Copyright (c) 2018 Lothar Wiemann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
}

unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, SynaSer, LCLType, Buttons, StrUtils, LazLogger;

type

  { TForm1 }

  TForm1 = class(TForm)
    ConnectButton: TButton;
    CmdLabel: TLabel;
    HintLabel: TLabel;
    MsgLabel: TLabel;
    Panel2: TPanel;
    TestButton: TButton;
    CtrlButton: TButton;
    FWButton: TButton;
    OpenDialog1: TOpenDialog;
    ProgressBar1: TProgressBar;
    ComTestButton: TButton;
    ComSelectBox: TComboBox;
    ComPortButton: TButton;
    Header: TLabel;
    StatusHeader: TLabel;
    CmdWindow: TMemo;
    StatusLabel: TLabel;
    MsgWindow: TMemo;
    Panel1: TPanel;
    CtrlPanel: TPanel;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure ConnectButtonClick(Sender: TObject);
    procedure CtrlButtonClick(Sender: TObject);
    procedure FWButtonClick(Sender: TObject);
    procedure CmdWindowKeyPress(Sender: TObject; var Key: char);
    procedure ComSelectBoxChange(Sender: TObject);
    procedure ComPortButtonClick(Sender: TObject);
    procedure SendCommand(Sender: TObject; const Command: string; var RetStr: string);
    procedure SendDACString(Sender: TObject; const Command: string; var RetStr: string);
    procedure ComTestButtonClick(Sender: TObject);
    procedure TestButtonClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);


  private

  public

  end;

var
  Form1                                                            : TForm1;
  ser                                                              : TBlockSerial;
  MsgStringList                                                    : TStringList;
  DacVersion, TLineDelay                                           : Integer;
  Receiving, Connected, Scroll, TXActive, RecoveryMode, MoniMode   : Boolean;
  cmd, LastRecStr, ComPort                                         : string;


const
  RecTimeOut                                  : integer = 40;
  ErrTime0ut                                  : integer = 9997;
  MaxOutlines                                 : integer = 80;

implementation

{$R *.lfm}

{ TForm1 }
//------------------------------------------------------------------------------
procedure delay(sn : double);
var
  t:double;
begin
  t := now+(sn/(24*60*60*1000));
  repeat
   sleep(5);
   Application.ProcessMessages;
  until now>t;
end;
//------------------------------------------------------------------------------
// wait until DAC8DSD quiet..
procedure UntilDACQuiet(var rStr: string);

var       rChr                  : Byte;

begin
  rStr:='';
  repeat                          // clear queue of RXed Bytes..
    rChr:=ser.RecvByte(50);
    if not ser.LastError=ErrTime0ut then rStr:=rStr+char(rChr);
  until ser.LastError=ErrTime0ut;
end;

procedure Dbg(const outstring: AnsiString);
begin
      DebugLn('Dbg : '+outstring);
end;


procedure  SendStr(var command: AnsiString);
begin
  DebugLn('Cmd : '+command);
  ser.SendString(command);
end;

//------------------------------------------------------------------------------
// add a character to Memo
procedure AddNewLine(Memo: TMemo);
begin
  Memo.Lines.Add('');
end;

procedure AddCharacter(Memo: TMemo; const C: Char);
var
  Lines: TStrings;
begin
  Lines := Memo.Lines;
  if Lines.Count=0 then
    AddNewLine(Memo);
  Lines[Lines.Count-1] := Lines[Lines.Count-1]+C;
end;

//------------------------------------------------------------------------------
// add a line to MemoX
procedure AddLineQ(Memo: TMemo; OutStr: string);

var       NumOutLines    : integer;

begin
  if not TxActive then DebugLn('Msg : '+OutStr);
  NumOutLines:=MsgStringList.Count;
  while NumOutLines>(MaxOutlines-1) do begin
     MsgStringList.Delete(0);
     NumOutLines:=NumOutLines-1;
  end;
  MsgStringList.Add(OutStr);
  Memo.Lines.Assign(MsgStringList);    //dem Window den Inhalt der StringList zuweisen
  if Scroll then Memo.SelStart := Length(Memo.Lines.Text);
//  Application.Processmessages;
end;

// add a line to MemoX
procedure AddLine(Memo: TMemo; OutStr: string);
begin
  AddLineQ(Memo, OutStr);
  Application.Processmessages;
end;

// send a command (silently without messages appearing on OutputWindow)
procedure TForm1.SendCommand(Sender: TObject; const Command: string; var RetStr: string);

var       SCmd                       : AnsiString;

begin
     SCmd:=Command+#13+#10;
     SendDACString(self, SCmd, RetStr);
end;


procedure TForm1.SendDACString(Sender: TObject; const Command: AnsiString; var RetStr: AnsiString);
var rStr            : string;
    ChrIn, rChr     : Char;
    i               : integer;

begin
  if Connected then
  begin
   DebugLn('CmC : '+Command);
   UntilDACQuiet(rStr);
//   AddLine(MsgWindow, 'SendCommand RXed while waiting for QUIET: '+rStr);
//   AddLine(MsgWindow, 'SendCommand sending: '+Command);

   RetStr:='';
   for i:=1 to Length(Command) do begin
     ser.SendByte(ord(Command[i]));
     ChrIn:=Char(ser.RecvByte(50));
     if (not (ser.LastError=ErrTime0ut)) then RetStr:=RetStr+ChrIn;
   end;
//   AddLine(MsgWindow, 'Return Bytes received: '+RetStr);

   RetStr:=ser.RecvString(500);     // receive reply
//   AddLine(MsgWindow, 'SendCommand: ReturnString received: '+RetStr);

   if not ser.LastError=ErrTime0ut then begin
    rStr:='';
    repeat                          // wait for further messages from DAC8DSD
      rChr:=char(ser.RecvByte(200));
      if (not (ser.LastError=ErrTime0ut)) then rStr:=rStr+rChr;
    until ser.LastError=ErrTime0ut;
//    AddLine(MsgWindow, 'SendCommand: Bytes received while wait: '+rStr);
    end;

  end
  else AddLine(MsgWindow, 'ERROR(SendCommand): not connected !');
end;

procedure TForm1.ComTestButtonClick(Sender: TObject);
  
var       lcmd, lRecvStr       : string;
          i, k, l, m           : integer;
          CommOK               : boolean;

const     j                    : integer = 50; //250;

begin
   AddLine(MsgWindow, 'Testing Communication - Please Wait ...');
   SendCommand(self, 'NTF 0', lRecvStr);
   Sleep(100);
   UntilDacQuiet(lRecvStr);
   Sleep(100);
   ComTestButton.Enabled:=false;
   Timer1.enabled:=false;
   TXActive:=true;
 //  ConnectButton.Enabled:=false;
   ProgressBar1.visible:=true;
   CommOK:=true;

   for k:= 1 to j do begin
     if NOT CommOK then Break;

     m:= trunc((k/j)*100);
     if (m mod 5)=0 then begin
      ProgressBar1.Position:=m+1;  // work-around to correctly show progressbar
      ProgressBar1.Position:=m;
     end;

     lcmd:='';                     // set up random command
     for i:= 1 to 6 do begin       // 6 groups a 4 char
       lcmd:=lcmd+hexStr(Random(65535),4);
       if i<6 then lcmd:=lcmd+' ' else lcmd:=lcmd+#13+#10;;
     end;

     UntilDACQuiet(lRecvStr);
     lRecvStr:='';
     ser.SendString(lcmd);                         // send string to DAC
  //   mit pausen senden !!!!
     lRecvStr:=ser.RecvString(RecTimeOut);         // receive ECHO string

     if (lRecvStr<>'') then begin
        if lRecvStr[1]='>' then Delete(lRecvStr, 1,1);
        AddLine(MsgWindow, (format('%3s',[IntToStr(k)])+'   '+lRecvStr));
        l:=Length(lcmd);
        if Length(lRecvStr)<l then l:= Length(lRecvStr);
        for i:= 1 to l do if lcmd[i]<>lRecvStr[i] then
          begin
            CommOK:=false;
            AddLine(MsgWindow, 'Communication Test ERROR !!!');
            Dbg('ComTestError - Line : '+(IntToStr(k)));
            Dbg('Bytes sent          : '+lcmd);
            Dbg('Bytes received      : '+lRecvStr);
          end;
        end
     else begin
        CommOK:=false;
        AddLine(MsgWindow, 'Communication Test Timeout ERROR !!!');
        Dbg('ComTestError - Line : '+(IntToStr(k)));
        Dbg('Bytes sent          : '+lcmd);
        Dbg('Bytes received      : '+lRecvStr);
     end;
  end;
  ProgressBar1.visible:=false;
  UntilDACQuiet(lRecvStr);  // wait until DAC8DSD quiet..   // discard "BAD COMMAND"

  if CommOK then begin
    ComTestButton.visible:=false;
    FWButton.visible:=true;
    FWButton.enabled:=true;
    CtrlButton.Caption:='Control';
    CtrlButton.visible:=true;
    CtrlButton.enabled:=true;
  end;

  TXActive:=false;
  if CommOK then AddLine(MsgWindow, 'Communication Test : Success.');
  SendCommand(self, 'NTF 2', lRecvStr);
  Sleep(100);
end;

procedure TForm1.TestButtonClick(Sender: TObject);
var       i                              : integer;
          chS, chR                       : char;
          SendS, RecS, TstS              : string;
          FlashErr                       : boolean;

begin
          FlashErr:=false;
          SendS:='@18000'+#13+#10;

          for i:=1 to Length(SendS) do begin
          sleep(10);
          chS:= SendS[i];
          TstS:=TstS+chS;
          chR:=char(0);
          ser.SendByte(ord(chS));
          chR:=char(ser.RecvByte(100));
          AddLine(MsgWindow, TstS);
//          if (not (ser.LastError=ErrTime0ut)) then
          begin
            RecS:=RecS+chR;
            AddLine(MsgWindow, RecS);
          end;
        {  if chR<>chS then begin
                             FlashErr:=true;
                             AddLine(MsgWindow, 'Communication ERROR...');
                             AddLine(MsgWindow, SendS);
                             RecS:=IntToStr(i)+' '+RecS;
                             AddLine(MsgWindow, RecS);
                           end
          else AddLine(MsgWindow, SendS);
          }
          if FlashErr then break;
          end;    // 1 line completely sent
end;

procedure TForm1.Timer1Timer(Sender: TObject);
   var    RecvStr:     string;

begin
  RecvStr:=ser.RecvString(1);
  if RecvStr<>'' then begin
     AddLine(MsgWindow, RecvStr);
     if RecvStr[1]='#' then
     begin
      if not Monimode then begin
       CmdLabel.Caption:='Command (Bootloader)';
       MoniMode:=true;
      end;
      MoniMode:=true;
     end;
     if ((RecvStr[1]='$')) then
     begin
      if Monimode then begin
       CmdLabel.Caption:='Command';
       MoniMode:=false;
      end;
     end;
     RecvStr:='';
     Application.Processmessages;
  end;
end;

//----------------------------------------------------------------------------
// Connect to DAC8DSD
procedure ComConnect(MsgWindow:TMemo);

var       lRecvStr,VerStr,VerPatt,RawVerS       : string;
          PosVer                                : longInt;
          i                                     : integer;

begin

  AddLine(MsgWindow, 'Connecting to ... '+ComPort);
  Connected:=false;
  RecoveryMode:=false;

        try
           ser.Connect(ComPort); //ComPort
           Sleep(100);
           ser.config(38400, 8, 'N', SB1, False, False);
           AddLine(MsgWindow, 'Device: ' + ser.Device + '   Status: ' + ser.LastErrorDesc +' '+ Inttostr(ser.LastError));
           if ser.LastError = 0 then
           begin
             ser.ConvertLineEnd:=true;
             AddLine(MsgWindow, 'Probing DAC8DSD connection... ');

             lRecvStr:='';
             ser.SendString('ECHO ON'+#13+#10);     // switch DAC8DSD ECHO function ON
             lRecvStr:=ser.RecvString(RecTimeOut);

             lRecvStr:='';
             ser.SendString('FW ?'+#13+#10);
             lRecvStr:=ser.RecvString(RecTimeOut);
             if lRecvStr = '>FW ?' then
               begin
                 AddLine(MsgWindow, 'DAC8DSD connection established ... ok');
                 Connected:=true;

                 AddLine(MsgWindow, 'checking DAC8DSD firmware... ');
                 lRecvStr:=ser.RecvString(RecTimeOut);

                 if lRecvStr<>'' then
                 begin
                   lRecvStr:=RightStr(lRecvStr,20);
                   VerPatt:='V??.';
                   PosVer:=FindPart(VerPatt,lRecvStr);
                   RawVerS:=AnsiMidStr(lRecvStr, PosVer, (Length(lRecvStr)-(PosVer)));
                   AddLine(MsgWindow, 'DAC8DSD firmware version = '+RawVerS);

                   VerStr:='';
                 //  for i:=1 to Length(RawVerS) do begin
                   for i:=1 to 6 do begin
                   if not ((i=1) and (RawVerS[i]='V')) then
                     case RawVerS[i] of
                       '0'..'9': VerStr:=VerStr+RawVerS[i];
                       'A'..'Z': VerStr:=VerStr+IntToStr(ord(RawVerS[i])-55);
                     end;
                   end;
                   if VerStr<>'' then DacVersion:=StrToInt(VerStr) else DacVersion:=0;
                   Dbg('DAC8DSD firmware NUMBER = '+IntToStr(DacVersion));
                 end;
               end
             else
               begin
              //   AddLine(MsgWindow, 'Received Line : '+ lRecvStr);
                 if LeftStr(lRecvStr,2)='#>' then
                   begin
                     AddLine(MsgWindow, 'DAC8 or DAC8DSD in recovery mode detected.');
                     Connected:=true;
                     RecoveryMode:=true;
                   end
                 else AddLine(MsgWindow, 'ERROR:  DAC8 not responding !');
               end;
             UntilDACQuiet(lRecvStr);
          end;

        except
           AddLine(MsgWindow, 'ERROR can not connect to Serial Port !'+ComPort);
        end;
        if not connected then
          if ser.InstanceActive then
                           begin
                             Ser.Flush;       // discard any remaining output
                             Ser.CloseSocket;
                           end;
end;

procedure TForm1.ComPortButtonClick(Sender: TObject);
begin
  Timer1.Enabled := false;
  ComSelectBox.Visible := true;
  ComSelectBox.Enabled := true;
end;


procedure TForm1.ComSelectBoxChange(Sender: TObject);
begin
   //ComSelectBox.Enabled := false;
   ComPort := ComSelectBox.Items[ComSelectBox.ItemIndex];  // get selected COM Port
   AddLine(MsgWindow, 'COM Port '+ComPort+' selected');
   //ComPortButton.Caption := 'Connect';
   ConnectButton.visible:=true;
end;

procedure TForm1.CmdWindowKeyPress(Sender: TObject; var Key: char);

var       nLine: integer;
          cmdLF: string;

begin
 if Key = #13 then                        // ENTER ?
 begin
   if connected then begin
     nLine:=CmdWindow.Lines.Count-1;
     cmd:=CmdWindow.Lines[nLine];
     cmd:=UpperCase(cmd);                 // to DAC8DSD only uppercase
     if MoniMode then cmd:=DelSpace(cmd); // no spaces in bootloader
     cmdLF:=cmd+#13+#10;                  // add LF & send it to DAC
     SendStr(cmdLF);
     if cmd='PROG' then begin
       MoniMode:=true;
       CmdLabel.Caption:='Command (Bootloader)';
     end;
   end
   else begin
     cmd:='';
     AddLine(MsgWindow, 'ERROR: Not Connected !');
   end;
 Application.Processmessages;
 end;
end;

procedure TForm1.FWButtonClick(Sender: TObject);
  var filename, SendS, RecS, RetS, CpS, ChkS    : string;
      fwFile                                    : TextFile;
      fwFileOpen, FlashErr, StopFlash           : boolean;
      i,j,FSize,Reply, CkSRes                   : integer;
      k                                         : Real;

begin
  Timer1.Enabled:=false;
  StopFlash:=false;
  fwFileOpen:= false;
  ConnectButton.Enabled:=false;

  if not RecoveryMode then                      // Check Power State
   begin
    SendCommand(self, 'PWR ?', RetS);           // is Power ON ?
    AddLine(MsgWindow, 'DAC PWR return: '+RetS);
    if RetS='$PWR: OFF' then begin
      ShowMessage('ERROR :  DAC8DSD not powered ON');
      StopFlash:=true;
    end;
   end;

  if not StopFlash then begin
     ComPortButton.Enabled:=false;
     ConnectButton.Enabled:=false;
     ComTestButton.Enabled:=false;
     FWButton.Enabled:=false;
     CtrlButton.Enabled:=false;

     AddLine(MsgWindow, 'Open File');
     FWButton.Color:=clRed;

     // Open Firmware File
     if OpenDialog1.Execute then
     begin
       filename := OpenDialog1.Filename;
  //     filename:='C:\lazarus\Projects\DAC8_FW_Updater\test.txt';
       AddLine(MsgWindow, filename);
       AssignFile(fwFile, filename);
       FSize:=FileSize(filename);                    // get filesize for progressbar
       AddLine(MsgWindow, 'FileSize= '+IntToStr(FSize));
       k:= FSize/5000;
       fwFileOpen := true;                           // assume file will be opened
       try                                           // Open the file for reading
         reset(fwFile);
       except
       on E: EInOutError do
         begin
           Dbg('OpenFile Error. fwFile = '+filename+' could not be opened.');
           Application.MessageBox('File error occurred.', 'ERROR',MB_ICONINFORMATION);
           fwFileOpen := false;
           StopFlash:=true;
         end;
       end;
     end
     else
     begin
       AddLine(MsgWindow, 'Error : No File selected. Quitting flash routine...');
       StopFlash:=true;
     end;

// Last Chance to quit !!!!!
     if not StopFlash then begin
       Reply := Application.MessageBox('Start Flash ?     Press "No" to quit', 'Start Flash', MB_ICONQUESTION + MB_YESNO);
       if Reply=IDNO then StopFlash:=true;
     end;
  end;


 if not StopFlash then begin
 Form1.Enabled:=false;
 HintLabel.Caption:='Programming ......'+LineEnding+'DO NOT INTERRUPT'+LineEnding+'DO NOT DISCONNECT';
 HintLabel.Visible:=true;
 if not RecoveryMode then begin
   AddLine(MsgWindow, 'Entering Bootloader ..... ');
   SendCommand(self, 'PROG', RetS);              // enter DAC Monitor-Routine
   sleep(1000);
 end;

   while not StopFlash do begin
     ProgressBar1.Position:=0;
     reset(fwFile);
     fwFileOpen := true;
     AddLine(MsgWindow, '');
     AddLine(MsgWindow, 'ERASING Memory ..... ');
     SendCommand(self, 'E', RetS);                // erase
     UntilDACQuiet(RetS);

     AddLine(MsgWindow, 'UPLOADING Program ..... ');
     SendDACString(self, 'U', RetS);              // Upload
     UntilDACQuiet(RetS);

// Keep reading lines until the end of the file is reached
     ProgressBar1.visible:=true;
     AddLine (MsgWindow, 'Flash LineDelay : '+(IntToStr(TLineDelay))+' ms');
     TxActive:=true;
     FlashErr:=false;
     i:=0;
     while not (eof(fwFile) or FlashErr) do
     begin
       readln(fwFile, SendS);
       AddLineQ(MsgWindow, (format('%5s',[IntToStr(i)])+'   '+SendS));
       ser.SendString(SendS+#13+#10);
       RecS:=ser.RecvString(100);
       if SendS<>RecS then begin
           FlashErr:=true;
           AddLine(MsgWindow, 'Error !   : ');
           if RecS='NX' then
             begin
               AddLine (MsgWindow, 'FlashError - Line : '+(IntToStr(i))+' Received  : '+RecS+'  Byte not blank');
               Dbg('FlashError - Line : '+(IntToStr(i))+' Received  : '+RecS+'  Byte not blank');
             end
           else begin
             AddLine(MsgWindow, 'TXed Line : '+SendS);
             AddLine(MsgWindow, 'Received  : '+RecS);
             Dbg('FlashError - Line : '+(IntToStr(i)));
             Dbg('Bytes sent        : '+SendS);
             Dbg('Bytes received    : '+RecS);
           end;
       end;
   //    sleep(TLineDelay);                           // Line Delay
       delay(TLineDelay);                             // incl. ProcessMessages
       if SendS[1]='q' then break;                // EndChar ?

       j:= trunc(i/k);
       ProgressBar1.Position:=j+1;  // work-around to correctly show progressbar
       ProgressBar1.Position:=j;
       i:=i+1;
     end;

  //   SendDACString(self, ('q'+#13+#10), RetS); // End Programming Mode
     TxActive:=false;
     Form1.Enabled:=true;

// test for programming fault
     if FlashErr then
         begin
           Reply := Application.MessageBox('Try again ?', 'Programming ERROR', MB_ICONQUESTION + MB_YESNO);
           if Reply = IDNO then StopFlash:=true
           else begin
             AddLine(MsgWindow, 'Trying again ....... ');
             AddLine(MsgWindow, '');
             TLineDelay:=30;                  // slower programming next time.
           end;
     end;

// Check Check-Sum
     if not (FlashErr or StopFlash) then
       begin
         AddLine(MsgWindow, 'Checking Checksum ....... ');
         sleep(200);
         CkSRes:=0;

         SendDACString(self, ('C'), RetS);   // request Checksum
         CpS:=RetS;
         RetS:=DelChars(CpS,(' '));
         AddLine(MsgWindow, '  Checksum Mem  : '+RetS);

         readln(fwFile, CpS);
         ChkS:=DelChars(CpS,(' '));
         AddLine(MsgWindow, '  Checksum File : '+ChkS);
         if RetS<>ChkS then CkSRes:=CkSRes+1;

         SendDACString(self, ('X'), RetS);        // request XtendedChecksum
         CpS:=RetS;
         RetS:=DelChars(CpS,(' '));
         if RetS<>'' then AddLine(MsgWindow, 'X_Checksum Mem  : '+RetS)
         else AddLine(MsgWindow, 'X_Checksum Mem  : not available');

         readln(fwFile, CpS);
         if CpS<>'' then
           begin
             ChkS:=DelChars(CpS,(' '));
             AddLine(MsgWindow, 'X_Checksum File : '+ChkS);
             if RetS<>'' then if RetS<>ChkS then CkSRes:=CkSRes+100;
           end
           else AddLine(MsgWindow, 'X_Checksum File : not available');

         if CkSRes=0 then begin
           AddLine(MsgWindow, 'FW Update: SUCCESS');
           AddLine(MsgWindow, 'Leaving Programming Mode ...... ');
           StopFlash:=true;        // ChkSum OK -> End
           AddLine(MsgWindow, 'Re-Starting DAC 8 DSD');
           SendCommand(self, 'G', RetS);               // GO
           AddLine(MsgWindow, 'Please wait ...... ');
           sleep(2000);
           SendCommand(self, 'PWR ON', RetS);          // Switch ON
         end
         else begin
           CpS:='ERROR  '+IntToStr(CkSRes);
           Reply := Application.MessageBox('Checksum ERROR - Try again ?', PChar(CpS), MB_ICONQUESTION + MB_YESNO);
           if Reply = IDNO then StopFlash:=true
           else begin
             AddLine(MsgWindow, 'Trying again ....... ');
             AddLine(MsgWindow, '');
           end;
         end;
       end;
     CloseFile(fwFile);             // Done. Close the file
     fwFileOpen:=false;
   end;
  end;
  sleep(100);
  if fwFileOpen then CloseFile(fwFile);
  HintLabel.Visible:=false;
  ProgressBar1.Visible:=false;
  ComPortButton.Enabled:=true;
  ConnectButton.Enabled:=true;
  FWButton.Enabled:=true;
  CtrlButton.Enabled:=true;
  ConnectButton.Enabled:=true;
  end;

procedure TForm1.CtrlButtonClick(Sender: TObject);
var       RetStr                         : string;

begin
 if  CtrlButton.Caption='Control' then begin
  Dbg('Entering Control Mode .....');
  ConnectButton.Enabled:=false;
  CtrlButton.Color:=clGreen;
  CtrlButton.Caption:='STOP Control';
  CmdWindow.Lines.Clear;
  FWButton.enabled:=false;
  CmdWindow.visible:=true;
  CmdLabel.visible:=true;
  Timer1.enabled:=true;
  if not RecoveryMode then SendCommand(self, 'NTF 2', RetStr);   // turn notification ON
 end
 else begin
  Dbg('Leaving Control Mode .....');
  CtrlButton.Color:=clDefault;
  CtrlButton.Caption:='Control';
  FWButton.enabled:=true;
  CmdWindow.visible:=false;
  CmdLabel.visible:=false;
  Timer1.enabled:=false;
  ConnectButton.Enabled:=true;
 end;
 end;

procedure TForm1.ConnectButtonClick(Sender: TObject);

var       RetS                              : string;

begin
  if not TxActive then begin
  case ConnectButton.Caption of
    'Disconnect':      begin
                         if not TXActive then begin
                           RecoveryMode:=false;
                           Progressbar1.Visible:=false;
                           FWButton.visible:=false;
                           CmdWindow.visible:=false;
                           CmdLabel.visible:=false;
                           CtrlButton.visible:=false;
                           ComTestButton.visible:=false;
                           Timer1.Enabled := false;
                           AddLine(MsgWindow, 'disconnecting ...');
                           ComPortButton.Enabled:=true;
                           StatusLabel.Caption := 'Disconnected';
                           StatusLabel.Color := clRed;
                           if ser.InstanceActive then
                             begin
                               Ser.Flush;       // discard any remaining output
                               Ser.CloseSocket;
                             end;
                           Connected:=false;
                           ConnectButton.Caption := 'Connect'
                         end;
                       end;

    'Connect':         begin
                         AddLine(MsgWindow, 'Connecting ...');
                         RecoveryMode:=false;
                         TLineDelay:=20;
                         ComConnect(MsgWindow);
                         if RecoveryMode then
                           begin
                             AddLine(MsgWindow, 'DAC in Recovery Mode detected.');
                             StatusLabel.Caption := 'DAC8(DSD) in RecoveryMode on '+ComPort;
                             StatusLabel.Color := $0007AAF8;
                             FWButton.caption:='Recover Firmware';
                             FWButton.visible:=true;
                             CtrlButton.visible:=true;
                             ComSelectBox.Enabled:=false;
                             ConnectButton.Caption := 'Disconnect';
                           end
                         else
                         if Connected then
                           begin
                             AddLine(MsgWindow, 'DAC found, connection established.');
                             ConnectButton.Enabled:=false;
                             ComSelectBox.Visible := false;
                             ComSelectBox.Enabled:=false;
                             ComPortButton.Enabled:=false;
                             SendCommand(self, 'PWR ON', RetS); // Power ON & get Device ident
                             if RetS='>' then RetS:=ser.RecvString(RecTimeOut);
                             case RetS of
                               'DAC 8 DSD' : StatusLabel.Caption:='DAC8 DSD connected to '+ComPort;
                               '>DAC 8'    : StatusLabel.Caption:='DAC 8 connected to '+ComPort;
                             else  StatusLabel.Caption:='DAC *** connected to '+ComPort;
                             end;
                             AddLine(MsgWindow, StatusLabel.Caption);
                             StatusLabel.Color := clLime;
                             AddLine(MsgWindow,'Gathering DAC Status Information - Please Wait ...');
                             sleep(5000);
                             ConnectButton.Caption := 'Disconnect'; // wait for DAC start-up message
                             ConnectButton.Enabled:=true;
                             ComTestButton.Visible:=true;
                             ComTestButton.Enabled:=true;
                             Timer1.Enabled := True;  // start Receiving Service
                           end
                         else
                           begin
                             Timer1.Enabled := false;
                             StatusLabel.Color := clRed;
                           end;
                       end;
  end;
  end;
end;

procedure TForm1.BitBtn1Click(Sender: TObject);
begin
  AddLine(MsgWindow, 'click ...');
end;


procedure TForm1.FormCreate(Sender: TObject);

begin
  DebugLn('---------------------------------------------------------------------');
  DebugLn('Starting....');
  MsgStringList:=TStringList.Create;   // StringList erstellen
  ser:=TBlockSerial.Create;            // Serial Interface

  Receiving:=false;
  Connected:=false;
  ComSelectBox.Items.CommaText := GetSerialPortNames();
  ComSelectBox.Visible:=false;
  ComPortButton.Caption := 'Select COM Port';

  MsgWindow.Lines.Clear;
  CmdWindow.Lines.Clear;

  Scroll:=true;     // default: scrolling = ON.

  if       Screen.Fonts.IndexOf('Courier New') <> -1 then
           MsgWindow.Font.Name := 'Courier New'
  else if  Screen.Fonts.IndexOf('DejaVu Sans Mono') <> -1 then
           MsgWindow.Font.Name := 'DejaVu Sans Mono'
  else if  Screen.Fonts.IndexOf('Courier 10 pitch') <> -1 then
           MsgWindow.Font.Name := 'Courier 10 pitch';

  Timer1.Interval := 10;
  Timer1.Enabled  := false;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Dbg('Destroying Form');
  Timer1.Enabled  := false;
  MsgStringList.Free;
  if ser.InstanceActive then
  begin
     Dbg('Destroying SerialInstance');
     Ser.Flush;       // discard any remaining output
     Ser.CloseSocket;
     Ser.Destroy;
  end;
  inherited;
end;




end.

