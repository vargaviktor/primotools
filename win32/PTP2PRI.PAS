program PTP2PRI;  { Primo PRI file -> Primo PTP file }
{Based on the wav2ptp program by joco}
{Based on the pri22ptp program by Varga Viktor}
{Programed by Viktor Varga <vargaviktor@pro.hu>}
{The program and source is free.}
{1.1 version, working OK, checked}

{uses crt;}
var
      f : file;
     fo : file;
      c : char;
      s : string;
  i,j,k : integer;
tadr,tnob,sadr: word;
    err : integer;
 inf,otf: string[100];
fnamelen: integer;
      b : byte;
 buffer : array[0..50000] of byte;
 priname: array[1..30] of string[32];
  pricrc: array[1..30] of longint;
  prisad: array[1..30] of word;
cvtfiles: integer;
    fCRC: longint;
    bfl : word;

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
  blktype : byte;
   blknum : byte;
      CRC : word;
    lastb : byte;
fsize, bsize: word;
    fname : string[32];
     last : boolean;

begin
CVTfiles:=0;
repeat

bfl:=0; {clear variables}
last:=false;
CRC:=0;
fCRC:=0;

repeat {wait for first $ff}
until getbyte_=$FF;
Writeln('Tape file header found...');

fsize:=GetByte_+(GetByte_ shl 8); {get a ptp file size}
WriteLn('Tape file size: $',hex(hi(fsize)),hex(lo(fsize)));

repeat
case Getbyte_ of {get tapeblock type}
$55: {normal block found}
    begin
    bsize:=GetByte_+(GetByte_ shl 8); {get blocksize}

    blktype:=Getbyte_; {get blocktype}
    case blktype of
         $83,$87:   {basic program/basic data nameblock}
             begin

             CRC:=0; {clearing variables}
             fCRC:=0;
             fnamelen:=0;
             fname:='';

             inc(CVTfiles,1); {increase number of converted files in this ptp}

             blknum:=Getbyte_; {get blocknumber}

             if blknum<>$00 then Writeln('Block number is not correct!');
             {in header block it must be equal with 00}

             fnamelen:=Getbyte_; {get filename length}
             fname[0]:=chr(fnamelen);
             inc(CRC,fnamelen);

             for i:=1 to fnamelen do  {get filename}
                 begin
                 b:=Getbyte_;
                 fname[i]:=Chr(b);
                 inc(CRC,b);
                 end;

             {converting filename to msdos compatible};
             for i:=1 to fnamelen do
                 begin
                 case ord(fname[i]) of
                      93:fname[i]:='A';
                      125:fname[i]:='a';
                      64:fname[i]:='E';
                      96:fname[i]:='e';
                      30:fname[i]:='i';
                      91:fname[i]:='o';
                      92:fname[i]:='O';
                      124:fname[i]:='o';
                      123:fname[i]:='o';
                      94:fname[i]:='U';
                      126:fname[i]:='u';
                      127:fname[i]:='u';
                      end;
                 end;

             {set the outfile name to the name found in the PTP}
             otf:=(copy(fname,1,8)+'.PRI');

             {store the prifile name in list for summary}
             priname[CVTfiles]:=otf;

             {print the filenames}
             Writeln('Filename in PTP: ',fname);
             Writeln('->PRI file name: ',otf);

             if lo(CRC)<>Getbyte_ then Writeln(' CRC error in the tape file!');
             {if the CRC in the file not equal with the calculated there was error.}
             end;
         $F1,$F5,$F7,$F9: {datablock}
             begin

             CRC:=0; {clearing CRC}

             case blktype of {checking block type for print}
                  $F1: s:='BASIC program';
                  $F5: s:='Screen';
                  $F7: s:='BASIC data';
                  $F9: s:='Machine-code';
                  end;

             case blktype of {convert and store blocktype}
                  $f1: Store($d1);
                  $f5: Store($d5);
                  $f7: Store($d7);
                  $f9: Store($d9);
                  end;

             blknum:=Getbyte_; {get block number}
             inc(CRC, blknum);

             tadr:=GetByte_+(GetByte_ shl 8); {get block load address}
             inc(CRC, lo(tadr));
             inc(CRC, hi(tadr));

             tnob:=Getbyte_; {get bytes of block}
             inc(CRC, tnob);

             if tnob=$00 then tnob:=$0100;
             {if number of bytes is 0 then modify to 256}

             StoreWord(tadr); {store load address}
             StoreWord(tnob); {store number of bytes}

             for j:=1 to tnob do
                 begin
                 b:=Getbyte;   {copy databytes from ptp to pri}
                 inc(CRC,b);
                 inc(fCRC,b);
                 end;

             if lo(CRC)<>Getbyte_ then Writeln(' CRC error in the tape file!');

             WriteLn('T->D - #',hex(blknum),'-',s);
         end;
    end;
    end;
$AA:
    begin
    CRC:=0;
    last:=true; {if the type is $aa this is the last block of this file}

    bsize:=GetByte_+(GetByte_ shl 8); {get blocksize}

    blktype:=Getbyte_; {get blocktype}

    case blktype of
         $B1,$B5,$B7: {basic prg/machine code prg/screen/BASIC data endblock}
             begin
             CRC:=0;

             blknum:=Getbyte_; {get block number}
             inc(CRC, blknum);

             if lo(CRC)<>Getbyte_ then Writeln(' CRC error in the tape file!');
             {if the CRC in the file not equal with the calculated there was error.}

             Store($c9); {store disk fileending}
             prisad[CVTfiles]:=0;

             WriteLn('T->D - #',hex(blknum),'-','End block.');

             end;
         $B9:   {auto started machine code endblock}
             begin
             CRC:=0;

             blknum:=Getbyte_; {get blocknumber}
             inc(CRC, blknum);

             sadr:=GetByte_+(GetByte_ shl 8); {get start address}
             inc(CRC, lo(sadr));
             inc(CRC, hi(sadr));

             if lo(CRC)<>Getbyte_ then Writeln(' CRC error in the tape file!');
             {if the CRC in the file not equal with the calculated there was error.}

             Store($c3); {store disk fileending with start address}
             Storeword(sadr);
             prisad[CVTfiles]:=sadr;

             WriteLn('T->D - #',hex(blknum),'-','End block. Start address: $',hex(hi(sadr)),hex(lo(sadr)),' (',sadr,')');
             end;
         end;

    { write out this pri file}
    pricrc[CVTfiles]:=fCRC;
    assign(fo,otf);
    {$I-}
    reset(fo,1); {existing?}
    if IOresult=0 then
       begin {if exists then quit}

       repeat
             writeln(otf,' file already exists or the name is invalid. Abort.');
             writeln('Please give a valid filename:');

             readln(otf);
             assign(fo,otf);

             reset(fo,1);

       until IOresult<>0;

       rewrite(fo,1);
       writeln('New file... (',otf,')');

       if IOresult<>0 then
          begin
          writeln('New file creation (',otf,') failed. Abort.');
          close(f);
          halt;
          end;
       end
    else
       begin {else writing out}
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

    {write out file from buffer, and close the output file}
    Blockwrite(fo,buffer,bfl);
    Close(fo);

    Writeln(otf,' is Done.');
    Writeln;

    end;
end;
until last;

until EoF(f);
{check the end of ptp file, if not, maybe there is other tape file in this ptp}

{writing out summary}

Writeln('Conversion summary:');
Writeln;
Writeln('        Filename         Raw CRC  Start address');
for i:=1 to CVTfiles do
    begin
    Write(priname[i]:16,pricrc[i]:16);
    if prisad[i]=0 then Writeln ('  BASIC') else
    Writeln('  $',hex(hi(prisad[i])),hex(lo(prisad[i])));
    end;
end;

BEGIN
{the only parameter needed is the ptp filename}
if paramcount=1 then
    begin
    inf:=paramstr(1);
    WriteLn;
    WriteLn('Converting .ptp file to .pri file(s)...');
    WriteLn;
    end
else
    begin  {if is not enough parameter write out the help}
    writeln('USE: ptp2pri inputfile');
    writeln('   inputfile: PTP file');
    writeln;
    writeln('  Output file names will be derived from the filename stored in PTP file.');
    writeln;
    writeln('For example:');
    writeln(' ptp2pri primo1.ptp');
    halt;
    end;

{open the source ptp file}
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

ConvertBlock; {call block converter}

END.
