{$g+}
program ptp2wav;

type
  mymem = array[0..65520] of byte;
 pmymem = ^mymem;

const

  SILENCE = $80;
 POS_PEAK = $f8;
 NEG_PEAK = $08;

{
 wavheader, 44 bajt, mono 8000 Hz-es wav fajl fejlec

 PRIMO "0" bit, 936 usec:  (2*) 8 minta, itt 1000 usec
 PRIMO "1" bit, 312 usec:  (2*) 3 minta, itt  375 usec


 PRIMO "csend", 0.25 masodpercig (250000 usec)

  [200 minta]


 PRIMO allomanyszinkron mezo:

  512 db $AA (10101010) byte, tehat 512*4*(16+6) = [45056 minta]

 PRIMO blokkszinkron mezo:

  96 db $FF byte, [468 minta] + 3 db $D3 (11010011) byte [234 minta]

}

var

  infile : file;
 outfile : file;
  wrtcnt : longint;
   pfptr : ^byte;
   bl_id : byte;
   bl_sz : word;
   bl_nr : word;
    perr : byte;
     whd : pointer;


procedure msg(const s:string);
begin
 writeln(s);
 inc(perr);
end;

procedure write_primo_silence;
var
 bf : array[0..1999] of byte;
begin
 if perr<>0 then exit;

 writeln('  write "silence" field');

 fillchar(bf,sizeof(bf),SILENCE);
 blockwrite(outfile,bf,sizeof(bf));
 inc(wrtcnt,sizeof(bf));
end;

const
 bt1 : array[0..05] of byte=(POS_PEAK,POS_PEAK,POS_PEAK,
                             NEG_PEAK,NEG_PEAK,NEG_PEAK);

 bt0 : array[0..15] of byte=(POS_PEAK,POS_PEAK,POS_PEAK,POS_PEAK,
                             POS_PEAK,POS_PEAK,POS_PEAK,POS_PEAK,
                             NEG_PEAK,NEG_PEAK,NEG_PEAK,NEG_PEAK,
                             NEG_PEAK,NEG_PEAK,NEG_PEAK,NEG_PEAK);

 wavhead : array[0..43] of byte=(82,73,70,70,0,0,0,0,87,65,86,69,102,109,116,32,16,0,0,0,1,0,1,0,64,31,0,0,64,31,
0,0,1,0,8,0,100,97,116,97,0,0,0,0);

procedure write_bit(bt:byte);
begin
 case (bt and 128) of
 0:
   begin
    blockwrite(outfile,bt0,sizeof(bt0));
    inc(wrtcnt,sizeof(bt0));
   end;
 128:
   begin
    blockwrite(outfile,bt1,sizeof(bt1));
    inc(wrtcnt,sizeof(bt1));
   end;
 end;
end;

procedure write_byte(b:byte);
var
   x,i : byte;
begin
 x:=b;
 for i:=0 to 7 do
  begin
   write_bit(x);
   x:=x shl 1;
  end;
end;

procedure write_primo_filesync;
var
   i : integer;
begin
 if perr<>0 then exit;

 writeln('  write "filesync" field');

 for i:=0 to 511 do write_byte($aa);
end;

procedure write_primo_blocksync;
var
   i : integer;
begin
 if perr<>0 then exit;

 {write('sync at ',wrtcnt,' ... ');}
 for i:=0 to 95 do write_byte($ff);
 for i:=0 to  2 do write_byte($d3);
 {writeln(wrtcnt);}
end;

function  get_next:byte;
begin
 get_next:=pfptr^;
 inc(pfptr);
end;

procedure write_primo_block;
var
   h,l : word;
     i : word;
begin
 if perr<>0 then exit;

 bl_id:=get_next;

 if not (bl_id in [$55,$aa]) then
  begin
   msg('Block ID error. ');
   exit;
  end;

     l:=get_next;
     h:=get_next;
 bl_sz:=(h shl 8) or l;

 inc(bl_nr);
 writeln('    write primo block #',bl_nr,', size=',bl_sz);

 for i:=1 to bl_sz do write_byte(get_next);
end;

procedure write_primo_file;
var
   inbuff : pmymem;
        b : byte;
        l : word;
begin
 new(inbuff);

 perr:=0;

 blockread(infile,b,1); { file id, must be $FF }

 if b<>$ff then msg('File ID error');

 blockread(infile,l,2); { primo file length    }
 dec(l,3); { size adjust }
 blockread(infile,inbuff^,l); { read the entire primo file (all blocks) }
 pfptr:=addr(inbuff^[0]);

 writeln('FILE write, size=',l);

 write_primo_silence;

 write_primo_filesync;

 bl_nr:=0;
 repeat
  write_primo_blocksync;
  write_primo_block;
 until (bl_id=$aa)or(perr<>0);

 writeln('FILE write done. (',bl_nr,' blocks)');
 write_primo_silence;

 dispose(inbuff);
end;

BEGIN
 wrtcnt:=0;
 if paramcount<>2 then
  begin
   writeln('USE: ptp2wav PTP-file WAV-file');
   halt;
  end;

 assign( infile,paramstr(1));
 assign(outfile,paramstr(2));

 perr:=0;
 {$I-}
 reset(infile,1);
 if IOresult<>0 then msg('Input file open error');
 rewrite(outfile,1);
 if IOresult<>0 then msg('Output file creation error');
 {$I+}

 if perr<>0 then halt;

 blockwrite(outfile,wavhead,44);

 wrtcnt:=0;

 repeat
  write_primo_file;
 until eof(infile)or(perr<>0);

 { correct wav size parameters }
 seek(outfile,40);
 blockwrite(outfile,wrtcnt,4); { data field size }
 seek(outfile,4);
 inc(wrtcnt,$24);
 blockwrite(outfile,wrtcnt,4); { RIFF field size }

 close(infile);
 close(outfile);

END. of program
