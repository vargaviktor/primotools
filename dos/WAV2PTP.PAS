program wav2ptp;  { WAV file -> Primo PTP file }

uses crt;

type

 txtID = array[0..3] of char;

 WAVhead = record
          riffID : txtID;
         riffLen : longint;
          waveID : txtID;
           fmtID : txtID;
          fmtLen : longint;
        wFormTag : word;
       nChannels : word;
   nSamplePerSec : longint;
  nAvgBytePerSec : longint;
     nBlockAlign : word;
        FormSpec : word;
 end;

 DATAdesc = record
          dataID : txtID;
         dataLen : longint;
 end;

 DATAdescPtr = ^DATAdesc;

var
      f : file;
     fo : file;
      c : char;
      s : string;
  i,j,k : integer;
      l : longint;
   head : WAVhead;
   data : DATAdesc;
   dofs : longint;
   dlen : longint;
    err : integer;
  fbuff : array[0..1023] of shortint;
  fbidx : integer;
   feof : boolean;
   fpos : longint;
   flst : integer;
    inf,
    otf : string[100];

     bf : array[0..639] of shortint;

         b : byte;
     c1,c2 : word;
    buffer : array[0..50000] of byte;
   w,q,bfl : word;
        fe : boolean;
      fact : real;

const
   hd : array[0..15] of char='0123456789ABCDEF';

  lim : shortint = 90;

  noiselim : integer =  3;
    bitlim : integer = 12;

function hex(x:byte):string;
begin
 hex:=hd[x shr 4]+hd[x and 15];
end;

function isID(id:txtID; const s:string):boolean;
begin
 isID:=(id[0]=s[1])and(id[1]=s[2])and(id[2]=s[3])and(id[3]=s[4]);
end;

procedure Store(x:byte);
begin
 buffer[bfl]:=x;
 inc(bfl);
end;

procedure StoreStr(const s:string);
var
   i : integer;
begin
 if length(s)=0 then exit;
 for i:=1 to length(s) do Store(byte(s[i]));
end;

procedure StoreWord(x:word);
begin
 Store(lo(x));
 Store(hi(x));
end;


function seekfordata:longint;
var
 buff : array[0..1023] of byte;
    i : integer;
  cur : longint;
    d : longint;
   id : ^txtID;
begin
 d:=0;
 cur:=filepos(f);
 blockread(f,buff,1024);
 for i:=0 to 1023-4 do
  begin
   id:=@(buff[i]);
   if isID(id^,'data') then d:=cur+i;
  end;
 seekfordata:=d;
end;

procedure msg(const s:string);
begin
 inc(err);
 writeln(s);
end;

function nextsample:shortint;
begin
 nextsample:=0;
 if feof then {exit;}
  begin
   close(f);
   writeln('End of WAV file. Abort.');
   halt;
  end;
 nextsample:=fbuff[fbidx]-128;
 inc(fbidx);
 inc(fpos);
 if fbidx=flst then
  begin
   if flst<>1024 then
    begin
     feof:=true;
     exit;
    end;
   blockread(f,fbuff,1024,flst);
   fbidx:=0;
  end;
end;

procedure WaitForHigh;
begin
 while nextsample<lim do;
end;

procedure NextPulse;
begin
 repeat
  WaitForHigh;
  c1:=1;
  while nextsample>=lim do inc(c1);
 until (c1>noiselim)and(c1<25);
 b:=b shl 1;
 if c1<bitlim then b:=b or 1;
end;

procedure SearchFileSync;
var j:word;
begin
 write('SearchFileSync ...');
 repeat
  NextPulse;
 until b=$ff;
 writeln('OK');
end;

function  GetByte_:byte;
var
   i : integer;
begin
 b:=0;
 for i:=0 to 7 do NextPulse;
 GetByte_:=b;
end;

function  GetByte:byte;
begin
 GetByte:=GetByte_;
 Store(b);
end;

function i2s(ll:longint):string;
var
  s : string[32];
begin
 str(ll,s);
 i2s:=s;
end;

procedure SearchBlockSync;
var
 s2,s3 : byte;
begin
 repeat
  NextPulse;
 until b=$d3;
 s2:=GetByte_;
 s3:=GetByte_;
 if (s2<>$d3)or(s3<>$d3) then
  begin
   msg('BlockSync error! ['+i2s(s2)+'|'+i2s(s3)+':'+i2s(fpos)+']. Abort');
   close(f);
   halt;
  end;
end;

function LoadBlock:boolean;
var
       i,j : integer;
         b : byte;
   blktype : byte;
    blknum : byte;
       CRC : word;
       sum : byte;
     wdata : word;
     bdata : byte;
     fname : string[32];
    buffer : array[0..255] of byte;
begin
 LoadBlock:=false;
 SearchBlockSync;

 blktype:=GetByte;
  blknum:=GetByte; CRC:=blknum;
 case blktype of

 $83,$87: { BASIC program/data name block }
     begin
      bdata:=GetByte;
      inc(CRC,bdata);
      fname[0]:=char(bdata);
      for i:=1 to bdata do
       begin
        b:=GetByte;
        fname[i]:=char(b);
        inc(CRC,b);
       end;
      sum:=GetByte;
      write(' #',hex(blknum),' ',fname,' BASIC ');
      if blktype=$83 then write('program') else write('data');
      if sum<>lo(CRC) then {msg('CRC error!');}writeln('CRC error!');
      writeln;
     end;

 $F1,$F5,$F7,$F9: { BASIC program/Screen/BASIC data/Machine-code block }
     begin
      case blktype of
       $F1: s:='BASIC program';
       $F5: s:='Screen';
       $F7: s:='BASIC data';
       $F9: s:='Machine-code';
      end;
      wdata:=(GetByte shl 8)+GetByte; {address}
      j:=GetByte; {length}
      inc(CRC,j);
      inc(CRC,lo(wdata));
      inc(CRC,hi(wdata));
      if j=0 then j:=256;
      for i:=0 to j-1 do
       begin
        b:=GetByte;
        buffer[i]:=b;
        inc(CRC,b);
       end;
      sum:=GetByte;
      write(' #',hex(blknum),' ',s);
      if sum<>lo(CRC) then {msg('CRC error!');}writeln('CRC error!');
      {writeln;}
     end;

 $B1,$B5,$B7,$B9:
     { BASIC,Machine-code/Screen/BASIC data/autostart machine-code end block }
     begin
      if blktype=$B9 then
       begin
        wdata:=(GetByte shl 8)+GetByte; {autostart address}
        inc(CRC,lo(wdata));
        inc(CRC,hi(wdata));
       end;
      sum:=GetByte;
      write(' #',hex(blknum),' END-block ');
      if blktype=$B9 then write(#13#10'Autotart addr=',wdata,'. ');
      if sum<>lo(CRC) then {msg('CRC error!');}writeln('CRC error!');
      writeln;
      LoadBlock:=true;
     end;

 end;
end;

BEGIN
 if paramcount in [2,3] then
  begin
   inf:=paramstr(1);
   otf:=paramstr(2);
   if paramcount=3 then
    begin
     val(paramstr(3),i,j);
     if (j=0) and (i<128)and(i>=20) then lim:=i;
     writeln('!!! Comparison limit set to ',lim,' !!!');
    end;
  end
 else
  begin
   writeln('USE: wav2ptp inputfile outputfile');
   writeln('  inputfile: WAV file (8 bit mono SR=22050Hz)');
   writeln(' outputfile: PTP file (existing or new Primo Tape file)');
   writeln('For example:');
   writeln(' wav2ptp primo1.wav out.ptp');
   halt;
  end;

 assign(f,inf);
 {$I-}
 reset(f,1);
 {$I+}
 if IOresult<>0 then
  begin
   writeln('Input file (',inf,') open error. Abort');
   halt;
  end;

 blockread(f,head,sizeof(head));

 err:=0;
 with head do
  begin
   if not isID(riffID,'RIFF') then msg('RIFF-id not found');
   if not isID(waveID,'WAVE') then msg('WAVE-id not found');
   if not isID( fmtID,'fmt ') then msg(' fmt-id not found');
   if err=0 then writeln('WAVE file IDs found');
   if wFormTag<>$0001 then msg('This is not a PCM wave data');
   if nChannels<>1 then msg('This is not a MONO audio file');
   writeln('Sample frequency = ',nSamplePerSec);
   if FormSpec<>$0008 then msg('This is not an 8 bit audio file')
                      else writeln('8 bit samples, good.');
   if nSamplePerSec<>22050 then
    begin
     fact:=nSamplePerSec/22050;
     noiselim:=round(noiselim*fact)-1;
       bitlim:=round(bitlim*fact)-1;
     writeln('WARNING: this is not a 22050 Hz sampled WAV');
     writeln('Noiselimit=',noiselim,' bitlimit=',bitlim);
    end;
  end;

 l:=seekfordata;
 if l<>0 then
  begin
   seek(f,l);
   blockread(f,data,sizeof(data));
   dofs:=l+8;
   dlen:=data.dataLen;
   writeln('DATA found, pos=',dofs,', length=',dlen);
  end
 else msg('DATA chunk not found in the audio file.');

 if err<>0 then halt;

 writeln('Press ENTER to parse the WAV or ESC to quit');
 c:=readkey;
 if c<>#13 then
  begin
   close(f);
   halt;
  end;

 {seek to 1st byte of data}
 seek(f,dofs);
 fbidx:=0;
 fpos:=0;
 feof:=false;
 blockread(f,fbuff,1024,flst);

  bfl:=0;
  SearchFileSync;
  Store($FF);     {file sign}
  StoreWord(0);

  repeat
   q:=bfl;
   Store($55); {block sign space}
   StoreWord(0);
   fe:=LoadBlock;
   w:=bfl;
   bfl:=q;
   if fe then Store($AA) else inc(bfl); {endblock sign or skip}
   StoreWord(w-q-3);
   bfl:=w;
  until fe;

  if err<>0 then
   begin
    close(f);
    writeln('Sorry, errors found in the WAV file. Abort');
    halt;
   end;


  { write file into the tapefile }
  q:=bfl; bfl:=1;
  StoreWord(q);  { length of file }
  bfl:=q;
  assign(fo,otf);
  {$I-}
  reset(fo,1); {existing?}
  if IOresult=0 then
   begin
    seek(fo,filesize(fo));
    writeln('File append... (',otf,')');
   end
  else
   begin
    rewrite(fo,1);
    writeln('New file... (',otf,')');
    if IOresult<>0 then
     begin
      writeln('New file creation (',otf,') failed. Abort.');
      close(f);
      halt;
     end;
   end;
  {$I+}
  blockwrite(fo,buffer,bfl);
  close(fo);
  writeln('DONE.');

 close(f);
END.