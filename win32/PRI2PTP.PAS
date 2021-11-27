program pri2ptp;  { Primo PRI file -> Primo PTP file }
{Based on the wav2ptp program by joco}
{Programed by Viktor Varga <vargaviktor@pro.hu>}
{The program and source is free.}
{1.0 version , this is OK now.}

uses crt;
var
      f : file;
     fo : file;
      c : char;
      s : string;
  i,j,k : integer;
    err : integer;
inf,otf : string[100];
   ptpf : string[16];
      b : byte;
CRCHead : word;
 buffer : array[0..50000] of byte;
w,q,bfl : word;

const
     hd : array[0..15] of char='0123456789ABCDEF';

function hex(x:byte):string;
begin
     hex:=hd[x shr 4]+hd[x and 15];
end;

function bcd(x:byte):byte;
begin
     if x >99 then bcd:=0;
     bcd:= ((x div 10) shl 4) or (x mod 10);
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

function GetByte_:byte;
var
   b : byte;
begin
Blockread(f,b,1);
GetByte_:=b;
end;

function GetByte:byte;
var
   b: byte;
begin
b:=GetByte_;
Store(b);
Getbyte:=b;
end;

function i2s(ll:longint):string;
var
  s : string[32];
begin
 str(ll,s);
 i2s:=s;
end;

procedure ConvertBlock;
var
       i,j : integer;
         b : byte;
blktype, prvblktyp : byte;
    blknum : byte;
fullb, marad : byte;
       CRC : word;
      fCRC : longint;
     lastb : byte;
dadr, dsadr, dnob : word;
     fname : string[32];
    buffer : array[0..255] of byte;
      last : boolean;
begin
last:=false;
blknum:=1;
prvblktyp:=0;
CRC:=0;
fCRC:=0;
Writeln('Converting...');
repeat

blktype:=GetByte_; {block type reading}
case blktype of
$D1,$D5,$D9: { BASIC program/Screen/BASIC-data/Machine-code block }
     begin
     dadr:=GetByte_+(GetByte_ shl 8); {get load address}
     dnob:=GetByte_+(GetByte_ shl 8); {get bytes of block}

     case blktype of {check block type for printing}
          $D1: s:='BASIC program';
          $D5: s:='Screen';
          $D7: s:='BASIC data';
          $D9: s:='Machine-code';
          end;

     prvblktyp:=blktype;

     {if a block is larger than normal tape block, it must be divided
     to smaller blocks}
     if dnob>256 then
     begin                        {create full length blocks}

     WriteLn('Dividing large disk block...');

     for i:= 1 to (dnob div 256) do
          begin
          CRC:=0;

          Store($55); {store block start sign}

          Store($06);
          Store($01); {store block lenght = $0106}

          case blktype of {store tape block type}
               $D1: Store($f1);
               $D5: Store($f5);
               $D7: Store($f7);
               $D9: Store($f9);
               end;

          Store(bcd(blknum)); {store block number}
          inc(CRC,bcd(blknum));

          StoreWord(dadr); {store load adress}
          inc(CRC,lo(dadr));
          inc(CRC,hi(dadr));

          Store($00); {number of bytes in this block=256}

          lastb:=blktype;
          {storin last block type, it needed to decide the type of the end block}

          {in some tape file we can find $64 databytes}
          {but in this converter we convert make full length blocks}

          for j:=0 to 255 do
              begin
              b:=Getbyte;
              inc(CRC,b);
              inc(fCRC,b);
              inc(dadr,1);
              end;

          Store(lo(CRC)); {store block CRC}

          WriteLn(' D=>T - #',hex(bcd(blknum)),'-',s);

          inc(blknum,1);{increase block number}
          end;

          {creating the partial length block}
          CRC:=0;

          Store($55); {store block start sign}
          StoreWord(($06+dnob mod 256)); {store block lenght = marad+$06}

          case blktype of {store tape block type}
                    $D1: Store($f1);
                    $D5: Store($f5);
                    $D7: Store($f7);
                    $D9: Store($f9);
                    end;

          Store(bcd(blknum)); {store block number in bcd}
          inc(CRC,bcd(blknum));

          StoreWord(dadr); {store load adress}
          inc(CRC,lo(dadr));
          inc(CRC,hi(dadr));

          Store(dnob mod 256); {store number of bytes in this block}
          inc(CRC,dnob mod 256);

          lastb:=blktype;
          {storin last block type, it needed to decide the type of the end block}

          {copying the bytes to a block which are the left}
          for j:=1 to (dnob mod 256) do
              begin
              b:=Getbyte;
              inc(CRC,b);
              inc(fCRC,b);
              inc(dadr,1);
              end;

          Store(lo(CRC)); {storing block CRC}

          WriteLn(' D=>T - #',hex(bcd(blknum)),'-',s);

          inc(blknum,1); {increase block number}

          end
     else
     begin
     {copying the normal or smaller length blocks}

     CRC:=0;

     Store($55); {store block start sign}
     StoreWord(($06+dnob)); {store block lenght = marad+$06}

     case blktype of {convert disk block type to tape block type}
               $D1: Store($f1);
               $D5: Store($f5);
               $D7: Store($f7);
               $D9: Store($f9);
               end;

     Store(bcd(blknum)); {store block number}
     inc(CRC,bcd(blknum));

     StoreWord(dadr); {store load adress}

     inc(CRC,lo(dadr));
     inc(CRC,hi(dadr));

     {if number of bytes=256 store 00 and add to CRC 00}
     {else store the number of bytes and add to the CRC too}
     if dnob=256 then Store($00) else Store(dnob);
     if dnob=256 then inc(CRC,$00) else inc(CRC,dnob);

     lastb:=blktype;
     {storin last block type, it needed to decide the type of the end block}

     for j:=1 to dnob do
         begin
         b:=Getbyte;
         inc(CRC,b);
         inc(fCRC,b);
         inc(dadr,1);
         end;

     Store(lo(CRC)); {storing block CRC}

     WriteLn('D->T - #',hex(bcd(blknum)),'-',s);

     inc(blknum,1); {increasing block number}
     end;
     end;

 $C3:
     { machine code end block }
     begin
     CRC:=0;

     Store($aa); {store last block start sign}

     Store($05);
     Store($00); {store block lenght = $0005}

     Store($b9); {block type}

     Store(bcd(blknum));   {store block number}
     inc(CRC,bcd(blknum));

     dsadr:=GetByte_+(GetByte_ shl 8); {get start address}
     StoreWord(dsadr);                 {store start adress}
     inc(CRC,lo(dsadr));
     inc(CRC,hi(dsadr));

     Store(lo(CRC)); {store block CRC}
     WriteLn('D->T - #',hex(bcd(blknum)),'-','End block. Start address: $',hex(hi(dsadr)),hex(lo(dsadr)),' (',dsadr,')');

     last:=true; {this was the last block we are ready}
     end;
 $C9:
     { BASIC,Screen/BASIC data end block }
     begin
     CRC:=0;

     Store($aa); {store last block start sign}

     Store($03);
     Store($00); {store block lenght = $0003}

     {end block type is the same like previous}
     {there is no clue about thism this was my decision!!!}
     case lastb of
          $D1: Store($b1);
          $D5: Store($b5);
          $D7: Store($b7);
          end;

     Store(bcd(blknum)); {store block number}
     inc(CRC,bcd(blknum));

     Store(lo(CRC)); {store block CRC}
     WriteLn('D->T - #',hex(bcd(blknum)),'-','End block.');
     last:=true; {this was the last block we are ready}
     end;

 end;

until last;
{writing out summary}

Writeln('Conversion summary:');
Writeln;
Writeln('        Filename         Raw CRC  Start address');
Write(ptpf:16,fCRC:16);
if dsadr=0 then Writeln ('  BASIC') else
Writeln('  $',hex(hi(dsadr)),hex(lo(dsadr)));

end;

BEGIN
if paramcount in [2,3] then
    begin
    inf:=paramstr(1);
    otf:=paramstr(2);
    if paramstr(3)='-n' then
         begin
         WriteLn('Please enter the file name, that you will store in the ptp file.');
         Write('>');
         Readln(ptpf);
         end
    else ptpf:='pri2ptp conv.';
    {ptpf:=Copy(ptpf,1,12)+" Cpf";}
    {if i will mark the files converted with this, this line should be used}
    if length(ptpf)>16 then ptpf:=Copy(ptpf,1,16); {cutting the longer filename}
    for i:=1 to length(ptpf) do
        begin
             case ptpf[i] of
             'µ': ptpf[i]:=chr(93);
             '†': ptpf[i]:=chr(125);
             'ê': ptpf[i]:=chr(64);
             'Ç': ptpf[i]:=chr(96);
             '÷': ptpf[i]:='I';
             '°': ptpf[i]:=chr(30);
             '‡': ptpf[i]:='O';
             '¢': ptpf[i]:=chr(91);
             'ô': ptpf[i]:=chr(92);
             'î': ptpf[i]:=chr(124);
             'ä': ptpf[i]:='O';
             'ã': ptpf[i]:=chr(123);
             'ö': ptpf[i]:=chr(94);
             'Å': ptpf[i]:=chr(126);
             'Î': ptpf[i]:='U';
             '˚': ptpf[i]:=chr(127);
             end;
        end;
    WriteLn;
    WriteLn('Converting .pri file to .ptp file.');
    WriteLn;
    WriteLn('Name stored in the ptp file:',ptpf);
    end
else
    begin
    writeln('USE: pri2ptp inputfile outputfile [-n]');
    writeln('   inputfile: PRI (.PRG) file');
    writeln('  outputfile: PTP file (existing or new Primo Tape file)');
    writeln('          -n: if this switch is there, you will be asked for the filename');
    writeln('              which will be stored into the .ptp file, else the default name');
    writeln('              will be stored: "pri2ptp conv." .');
    writeln('For example:');
    writeln(' pri2ptp primo1.pri primo1.ptp -n');
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

{seek to 1st byte of data}
Seek(f,0);
bfl:=0;
CRCHead:=0;

{create ptp file sing}
Store($FF);     {file sign}
StoreWord(0);

{create ptp head block}

Store($55); {block start sign}
Store(4+length(ptpf)); {block lenght = 12}
Store($00);

Store($83); {mixed blocks included}
Store($00); {block number in head is $00}
Store(Length(ptpf)); {file name lenght in PTP chars of the in outfile name}
StoreStr(ptpf); {file name}

CRCHead:=$00+Length(ptpf);
for i:=1 to Length(ptpf) do inc(CRCHead, Ord(ptpf[i])); {CRC of the head}
Store(lo(CRCHead));

ConvertBlock;

if err<>0 then
      begin
      close(f);
      writeln('Sorry, errors found in the PRI file. Abort');
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
Blockwrite(fo,buffer,bfl);
close(fo);
writeln('DONE.');

close(f);
END.
