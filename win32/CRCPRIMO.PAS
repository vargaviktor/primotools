program crcprimo;  { Creating a raw CRC from a PRI or a PTP file }
{Based on the wav2ptp program by joco}
{Based on the pri2ptp program by Varga Viktor}
{Based on the ptp2pri program by Varga Viktor}
{Programed by Viktor Varga <vargaviktor@pro.hu>}
{The program and source is free.}
{ -s parameter nem mukodik tape file eseteben rt100}

uses crt;
var
      f : file;
     fo : file;
      c : char;
      s : string;
  i,j,k : integer;
      l : longint;
    priname: array[1..100] of string[32];
  pricrc: array[1..100] of longint;
  prisad: array[1..100] of word;
  pripnam: array[1..100] of string[32];
   dofs : longint;
   dlen : longint;
    err : integer;
       CVTfiles: integer;
  fbidx : integer;
   feof : boolean;
   fpos : longint;
   flst : integer;
inf,otf : string[100];
   ptpf : string[16];
   fCRC : longint;

   fsize,bsize,tadr,sadr,tnob: word;
          fnamelen: integer;

      b : byte;
     c1,c2, CRCHead : word;
    buffer : array[0..50000] of byte;
   w,q,bfl : word;
        fe, long : boolean;
      fact : real;


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

procedure msg(const s:string);
begin
     inc(err);
     writeln(s);
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
procedure DoDiskCheck(ffbyte:byte);
var
   last,first: boolean;
   prvblktyp,blknum,blktype: byte;
   dadr,dnob,dsadr:word;
begin
     last:=false;
     first:=true;
     prvblktyp:=0;
     blknum:=0;
     fCRC:=0;

     inc(CVTfiles,1);

     Writeln(#10#13,'Checking disk file: ',inf);

     repeat
         {the first byte is the type of the first block}
         if first then blktype:=ffbyte else blktype:=Getbyte_;
         first:=false;

         case blktype of
          $D1,$D5,$D9: { BASIC program/Screen/BASIC-data/Machine-code block }
              begin
              dadr:=GetByte_+(GetByte_ shl 8); {get load address}
              dnob:=GetByte_+(GetByte_ shl 8); {get bytes of block}

              case blktype of
                   $D1: s:='BASIC program';
                   $D5: s:='Screen';
                   $D7: s:='BASIC data';
                   $D9: s:='Machine-code';
                   end;

              for j:=1 to dnob do
                  begin
                  b:=Getbyte;
                  inc(fCRC,b);
                  end;

              if long then WriteLn('D - #',hex(bcd(blknum)),'-',s);

              inc(blknum,1);
              end;
          $C3: { machine code end block }
              begin
              dsadr:=GetByte_+(GetByte_ shl 8); {get start address}
              if long then Write('D - #',hex(bcd(blknum)),'-','End block. ');
              if long then WriteLn('Start address: $',hex(hi(dsadr)),hex(lo(dsadr)),' (',dsadr,')');
              if long then Writeln('D - Raw CRC: ',fCRC);
              last:=true; {exit is ok}
              end;
          $C9: { BASIC,Screen/BASIC data end block }
              begin
              dsadr:=0;
              if long then Write('D - #',hex(bcd(blknum)),'-','End block. ');
              if long then WriteLn('Start address: BASIC');
              if long then Writeln('D - Raw CRC: ',fCRC);
              last:=true; {exit is ok}
              end;
         end;
     until last;

     if (filesize(f)-filepos(f))=1 then
                   begin
                        Writeln('D - There is a removable #$0D in the file.');
                        b:=getbyte_;
                   end;

     Priname[CVTfiles]:=inf;
     Pricrc[CVTfiles]:=fCRC;
     Prisad[CVTfiles]:=dsadr;
     Pripnam[CVTfiles]:='';


     close(f);

end;


procedure DoTapeCheck(ffbyte:byte);
var
   last,first,lasttf: boolean;
   prvblktyp,blknum,blktype: byte;
   dadr,dnob,dsadr,CRC:word;
   fname : string[32];
begin

last:=false;
fCRC:=0;

 Writeln(#10#13,'Checking tape file: ',inf);


repeat
      {the first byte is the type of the first block}

      lasttf:=false;


      if long then Writeln('T - Tape file header found...');

      fsize:=GetByte_+(GetByte_ shl 8); {get a ptp file size}
      if long then WriteLn('T - Tape file size: $',hex(hi(fsize)),hex(lo(fsize)));

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
                       Priname[CVTfiles]:=inf;

                       blknum:=Getbyte_; {get blocknumber}

                       if ((blknum<>$00) and long) then Writeln('T - Block number is not correct!');
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

                       {converting filename to printable}
                       for i:=1 to fnamelen do
                           begin
                           case ord(fname[i]) of
                                 93:fname[i]:='µ';
                                125:fname[i]:='†';
                                 64:fname[i]:='ê';
                                 96:fname[i]:='Ç';
                                 30:fname[i]:='°';
                                 91:fname[i]:='¢';
                                 92:fname[i]:='ô';
                                124:fname[i]:='î';
                                123:fname[i]:='ã';
                                 94:fname[i]:='ö';
                                126:fname[i]:='Å';
                                127:fname[i]:='˚';
                                end;
                           end;

                       {store the prifile name in list for summary}
                       pripnam[CVTfiles]:=fname;

                       {print the filenames}
                       if long then Writeln('T - Primo file found: ',fname,' in ',inf);

                       if (lo(CRC)<>Getbyte_) then Writeln('T - CRC error in the ',inf,'/',fname,' at block #',hex(blknum));
                       {if the CRC in the file not equal with the calculated there was error.}
                       end;{83,87 end}

                  $F1,$F5,$F7,$F9: {datablock}
                       begin

                       CRC:=0; {clearing CRC}

                       case blktype of {checking block type for print}
                            $F1: s:='BASIC program';
                            $F5: s:='Screen';
                            $F7: s:='BASIC data';
                            $F9: s:='Machine-code';
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

                       for j:=1 to tnob do
                           begin
                           b:=Getbyte_;   {read databytes from ptp}
                           inc(CRC,b);
                           inc(fCRC,b);
                           end;

                       if (lo(CRC)<>Getbyte_) then Writeln('T - CRC error in the ',inf,'/',fname,' at block #',hex(blknum));
                       if long then WriteLn('T - #',hex(blknum),'-',s);
                       end;{Fx end}
                  end; {case 83 fx begin endje}
                  end; {case 55 endje}
             $AA: {end block}
                   begin

                   CRC:=0;
                   lasttf:=true; {if the type is $aa this is the last block of this file}

                   bsize:=GetByte_+(GetByte_ shl 8); {get blocksize}

                   blktype:=Getbyte_; {get blocktype}

                   case blktype of
                       $B1,$B5,$B7: {basic prg/machine code prg/screen/BASIC data endblock}
                           begin
                           CRC:=0;

                           blknum:=Getbyte_; {get block number}
                           inc(CRC, blknum);

                           if lo(CRC)<>Getbyte_ then Writeln('T - CRC error in the ',inf,'/',fname,' tape file!');

                           {if the CRC in the file not equal with the calculated there was error.}

                           if long then Write('T - #',hex(blknum),'-','End block. ');
                           if long then WriteLn('Start address: BASIC');
                           if long then Writeln('T - Raw CRC: ',fCRC);

                           prisad[CVTfiles]:=0;
                           pricrc[CVTfiles]:=fCRC;

                           end;  {Bx end}
                       $B9:   {auto started machine code endblock}
                           begin
                           CRC:=0;

                           blknum:=Getbyte_; {get blocknumber}
                           inc(CRC, blknum);

                           sadr:=GetByte_+(GetByte_ shl 8); {get start address}
                           inc(CRC, lo(sadr));
                           inc(CRC, hi(sadr));

                           if long and (lo(CRC)<>Getbyte_) then Writeln('T - CRC error in the ',inf,'/',fname,' tape file!');
                           {if the CRC in the file not equal with the calculated there was error.}

                           prisad[CVTfiles]:=sadr;

                           if long then Write('T - #',hex(blknum),'-','End block. ');
                           if long then Writeln('Start address: $',hex(hi(sadr)),hex(lo(sadr)),' (',sadr,')');
                           if long then Writeln('T - Raw CRC: ',fCRC);

                           prisad[CVTfiles]:=sadr;
                           pricrc[CVTfiles]:=fCRC;

                           end; {b9 end}
                       end; {case Bx end}

                   end;{case aa end}
             end; {case aa 55 end}
                       {put the crc into statistic matrix}
             until lasttf;

             if (filesize(f)-filepos(f))=1 then b:=getbyte_;
             
             if (filesize(f)-filepos(f))>15 then
                   begin
                        repeat
                        until getbyte_=$ff;
                   end;


             until EoF(f);
             close(f);
             end;{ff ag end}


{end;}
{end;}

procedure Checkfile;
var
       i,j : integer;
         b : byte;
   blktype, prvblktyp : byte;
    blknum : byte;
       fullb, marad : byte;
       CRC : word;
       lastb : byte;
     wdata, dadr, dsadr, dnob, blen : word;
     bdata, ffbyte : byte;
     fname : string[32];
    buffer : array[0..255] of byte;
      last, first,lasttf: boolean;
begin
for k:=2 to paramcount do
    begin
    inf:=paramstr(k);
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

    ffbyte:=Getbyte_; {read the first byte of this file}
    first:=true;
    case ffbyte of
         $d1,$d5,$d7,$d9: DoDiskCheck(ffbyte); {this is a disk file (.PRI)}
         $ff: DoTapeCheck(ffbyte); {this is a tape file}
         end;
end; {for end}
end; {procedure end}


BEGIN

CVTfiles:=0;
if paramcount > 1 then
    if paramstr(1)='-l' then long:=true else long:=false
else
    begin
    writeln('USE: crcprimo -s|-l inputfile [inputfile] [inputfile...]');
    writeln;
    writeln('          -s: short info (name, raw CRC, start address');
    writeln('          -l: long info with block information');
    writeln('          inputfiles are PRI (.PRG) or PTP files');
    writeln('For example:');
    writeln(' crcprimo -s primo1.pri primo2.ptp primo3.pri');
    halt;
    end;

Checkfile;

Writeln;

For i:=1 to CVTfiles do
begin
     Write('File: ',Pripnam[i]:16,'/',Priname[i]:11,' Raw CRC: ',Pricrc[i]:8);
     If Prisad[i]=0 then Writeln(' Start: BASIC')
     else Writeln(' Start: $',hex(hi(Prisad[i])),hex(lo(Prisad[i])),' (',Prisad[i],')');
end;
END.
