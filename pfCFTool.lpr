{$IFDEF FPC}{$mode delphiunicode}{$codepage utf8}{$ENDIF}
{$DEFINE PoweredByOsminog}
program pfCFTool;
uses
  classes,sysutils,strutils,zlib,regexpr,u1CTools2 in 'u1Ctools2.pas',
  upfTools in 'upftools.pas';

{$IFDEF WINDOWS}
{$R *.res}
{$ENDIF}
const
  ProjectVersion='3.1.0';
{
2023-03-17 v 3.0.1
Первый публично-тестовый релиз

2023-03-24 v 3.0.2
* Исправления - корректная обработка пустых CF
* Исправления при расжатии пустых потоков
+ использование маски в "compare"

2023-03-25 v 3.1.0
* Различные исправления
+ переписан CFUpdate - имена файлов сортируются, используются TMemoryStream

}

const
  MaxStreamSizeForMemStream=64*1024*1024;//64Mb
type
  TUseCompression=(cRaw,cDeflate,cAuto);
var
  options:record
    action:(aHelp,aList,aPack,aUnpack,aCompare,aConvert,aTest,aInflate,aDeflate,aCFUInfo,aCFUpdate);
    dir:UnicodeString;
    fn,fn2,fn3:UnicodeString;
    recurse:boolean;
    compress:TUseCompression;
    useFormat,convertFormat:integer;
    nostub:boolean;
    stub:UnicodeString;
    mask:String;
    force:boolean;
  end = (action:aHelp;dir:'';fn:'';fn2:'';fn3:'';recurse:false;compress:cRaw;useFormat:0;convertFormat:0;nostub:false;stub:'';mask:'';force:false);

procedure ShowHelp();
var
  s:AnsiString;
begin
  writeln('pfCFTool v.',ProjectVersion,' by Pasha1st');
{$ifdef PoweredByOsminog}
  writeln('Powered by Osminog https://osminog.biz/');
  s:='Osminog - решение всех вопросов с обслуживанием 1С';
  writeln(s);
{$endif}
  writeln('Usage: pfCFTool [<parameters>]');
  writeln('  Parameters:');
  writeln('    -h | --help | help          Show this help');
  writeln('    -l | list <file>            List files in <file> container');
  writeln('    -u | unpack <file>          Unpack files (see -d -r -c)');
  writeln('    -p | pack <file>            Create container <file> from files');
  writeln('    -t | test <file>            Test container <file> (unpack to /dev/null)');
  writeln('    compare <file1> <file2>     Compare containters'' contents');
  writeln('    convert <file1> <file2>     Convert container format - auto (change), to classic or to new');
  writeln('    inflate <file1> <file2>     Inflate (decompress) file1 to file2');
  writeln('    deflate <file1> <file2>     Deflate (compress) file1 to file2');
  writeln('    cfuinfo <file1.cfu>         Short info about CFU');
  writeln('    cfupdate <file1.cf> <file2.cfu> <file3.cf>   Update file1.cf by file2.cfu and save as file3.cf');
  writeln('    -force                      For cfupdate - force update, do not check versions');
  writeln('    -d <dir>                    Directory to pack/unpack');
  writeln('    -r                          Recurse processing');
  writeln('    -c raw|deflate|auto         Compression, default raw (no processing)');
  writeln('    -cv 0|auto|1|classic|2|new  Use container format - auto, classic (up to 8.3.15), new (8.3.16+)');
  writeln('    -cnv 0|auto|1|classic|2|new Convert container format to - auto, classic (up to 8.3.15), new (8.3.16+)');
  writeln('    -stub <file>                Use this stub for new format');
  writeln('    -nostub                     Do not use stub for new format');
  writeln('    -M <dos-like mask>          Match filenames in Unpack/List');
  writeln('    -m <RegExp>                 Match filenames in Unpack/List');
end;

function DosLikeMaskToRegExp(mask:string):string;
var
  i:integer;
  suffix:string;
begin
  result:='';
  if mask='' then exit;
  if mask[1]='*' then begin
    Delete(mask,1,1);
    if mask='' then exit;
  end else begin
    result:='^';
  end;
  if mask[length(mask)]='*' then begin
    suffix:='';
    delete(mask,length(mask),1);
  end else begin
    suffix:='$';
  end;
  for i:=1 to length(mask) do begin
    case mask[i] of
      '*':result:=result+'.*';
      '?':result:=result+'.';
      '.','(',')','\','+','[',']','^','$','{','}','|':
        result:=result+'\'+mask[i];
    else
      result:=result+mask[i];
    end;
  end;
  result:=result+suffix;
//writeln('Mask: ',result);
end;

procedure ParseParameters;
var
  i:integer;
  s,sl:string;
begin
  i:=1;
  while i<=ParamCount do begin
    s:=ParamStr(i);
    sl:=lowercase(s);
    if (sl='-h')or(sl='--help')or(sl='help') then begin
      options.action:=aHelp;
    end else if (sl='-l')or(sl='list') then begin
      options.action:=aList;
      inc(i);
      options.fn:=ParamStr(i);
    end else if (sl='-u')or(sl='unpack') then begin
      options.action:=aUnpack;
      inc(i);
      options.fn:=ParamStr(i);
    end else if (sl='-p')or(sl='pack') then begin
      options.action:=aPack;
      inc(i);
      options.fn:=ParamStr(i);
    end else if (sl='-t')or(sl='test') then begin
      options.action:=aTest;
      inc(i);
      options.fn:=ParamStr(i);
    end else if (sl='compare') then begin
      options.action:=aCompare;
      inc(i);
      options.fn:=ParamStr(i);
      inc(i);
      options.fn2:=ParamStr(i);
    end else if (sl='convert') then begin
      options.action:=aConvert;
      inc(i);
      options.fn:=ParamStr(i);
      inc(i);
      options.fn2:=ParamStr(i);
    end else if (sl='inflate') then begin
      options.action:=aInflate;
      inc(i);
      options.fn:=ParamStr(i);
      inc(i);
      options.fn2:=ParamStr(i);
    end else if (sl='deflate') then begin
      options.action:=aDeflate;
      inc(i);
      options.fn:=ParamStr(i);
      inc(i);
      options.fn2:=ParamStr(i);
    end else if (sl='cfuinfo') then begin
      options.action:=aCFUInfo;
      inc(i);
      options.fn:=ParamStr(i);
    end else if (sl='cfupdate') then begin
      options.action:=aCFUpdate;
      inc(i);
      options.fn:=ParamStr(i);
      inc(i);
      options.fn2:=ParamStr(i);
      inc(i);
      options.fn3:=ParamStr(i);
    end else if (sl='-force') then begin
      options.force:=true;
    end else if (sl='-d') then begin
      inc(i);
      options.dir:=ParamStr(i);
    end else if (sl='-r') then begin
      options.recurse:=true;
    end else if (sl='-c') then begin
      inc(i);
      s:=lowercase(ParamStr(i));
      if s='deflate' then
        options.compress:=cDeflate
      else if s='auto' then
        options.compress:=cAuto;
    end else if (sl='-m') then begin
      inc(i);
      if s='-m' then
        options.mask:=ParamStr(i)
      else
        options.mask:=DosLikeMaskToRegExp(ParamStr(i));
    end else if (sl='-cv') then begin
      inc(i);
      sl:=lowercase(ParamStr(i));
      if (sl='0') or (sl='auto') then
        sl:='0'
      else if (sl='1') or (sl='classic') then
        sl:='1'
      else if (sl='2') or (sl='new') then
        sl:='2'
      else
        sl:='0';
      options.useFormat:=StrToIntDef(sl,0);
    end else if (sl='-cnv') then begin
      inc(i);
      sl:=lowercase(ParamStr(i));
      if (sl='0') or (sl='auto') then
        sl:='0'
      else if (sl='1') or (sl='classic') then
        sl:='1'
      else if (sl='2') or (sl='new') then
        sl:='2'
      else
        sl:='0';
      options.convertFormat:=StrToIntDef(sl,0);
    end else if (sl='-stub') then begin
      inc(i);
      options.stub:=ParamStr(i);
    end else if (sl='-nostub') then begin
      options.nostub:=true;
    end;

    if (options.dir<>'')and(not (options.dir[length(options.dir)] in [':','/','\'])) then
      options.dir:=options.dir+DirectorySeparator;
    inc(i);
  end;
end;

procedure DoUnpack();
var
  UnpackList:TStrings;

  procedure DoUnpackInt(outdir,fn:UnicodeString;recurse:boolean;usecompress:TUseCompression;mask:string;showProgress:boolean=true);
var
  cf:T1CContainer;
  st,st2:TStream;
//  zs:z_stream;
  zds:TpfzlibDecompressionStream;
  i,r:integer;
  buf:array of byte;
  err:boolean;
  decompress:boolean;
  regex:TRegExpr;
begin
  if fn='' then begin
      writeln('No file specified');
      exit;
  end else if not FileExists(fn) then begin
    writeln('File specified does not exist');
    exit;
  end;
  cf:=T1CContainer.Create(fn,options.useFormat);
  if (cf.FormatVersion=cfNew)and(not options.nostub) then begin
    fn:=outdir+'.stub';
    st:=TFileStream.Create(fn,fmCreate or fmShareDenyWrite);
    if Length(cf.Stub)>0 then
      st.Write(cf.Stub[0],Length(cf.Stub));
    st.Free;
  end;
  regex:=TRegExpr.Create;
  if mask<>'' then regex.Expression:=mask;
  regex.ModifierI:=true;
  try
    for i:=0 to (cf.DocumentsCount-1) do begin
      err:=false;
      if (mask<>'') and not regex.Exec(cf.Files[i].Name) then continue;
      fn:=outdir+cf.Files[i].Name;
      st:=TFileStream.Create(fn,fmCreate or fmShareDenyWrite);
     try
      try
        cf.ReadDocument(cf.Files[i].BlockOffset,st);

        decompress:=usecompress=cDeflate;
        if usecompress=cAuto then begin
            st.Seek(0,soBeginning);
            SetLength(buf,4096);
            r:=st.Read(buf[0],Length(buf));
            decompress:=TestBufferCompressed(buf[0],r,-15);
            st.Position:=0;
        end;

        if decompress then begin
            st2:=TFileStream.Create(fn+'.deflate',fmCreate or fmShareDenyWrite);
            st.Seek(0,soBeginning);
            zds:=TpfzlibDecompressionStream.CreateRawDeflate(st);

            try
              CopyStream(zds,st2);
            finally
              st2.Free;
              zds.Free;
            end;
        end;
        if recurse then begin
          if decompress then
            st2:=TFileStream.Create(fn+'.deflate',fmOpenRead or fmShareDenyWrite)
          else
            st2:=st;
          if TestIsStream1CContainer(st2) then
            UnpackList.Add(fn);
          if decompress then st2.Free;
        end;

      finally
        st.Free;
        if decompress then begin
            if err then
              writeln('Error inflating ',fn)
            else
              DeleteFile(fn);
        end;
      end;
     except
        on e:Exception do begin
          writeln(#$0d+cf.Files[i].Name+'      ');
          writeln('Exception '+e.Message);
        end;
     end;
      if showProgress then write(#$0d,i+1,' of ',cf.DocumentsCount,', ',(i+1)*100 div cf.DocumentsCount,'%');
    end;
  finally
    cf.Free;
    regex.Free;
  end;
end;

var
  fn,outdir:UnicodeString;
  n,total:integer;
begin
  UnpackList:=TStringList.Create;
  if options.recurse then writeln('Phase 1');
  DoUnpackInt(options.dir,options.fn,options.recurse,options.compress,options.mask);
  WriteLn;
  if options.recurse then writeln('Phase 2');
  total:=UnpackList.Count;
  n:=0;
  while UnpackList.Count>0 do begin
    fn:=UnpackList[0];
    if FileExists(fn+'.deflate') then begin
      outdir:=fn+DirectorySeparator;
      fn:=fn+'.deflate';
    end else begin
      outdir:=fn+DirectorySeparator;
      RenameFile(fn,fn+'.tmp');
      fn:=fn+'.tmp';
    end;
    UnpackList.Delete(0);
    if not DirectoryExists(outdir) then CreateDir(outdir);
    DoUnpackInt(outdir,fn,true,cRaw,'',false);
    DeleteFile(fn);
    inc(n);
    write(#$0d,n,' of ',total,', ',(n)*100 div total,'%     ');
  end;
  if options.recurse then writeln();
  UnpackList.Free;
end;

procedure DoPack();
  procedure DoPackInt(dir:UnicodeString;dst:T1CContainer;recurse:boolean;usecompress:TUseCompression);
  var
    cf:T1CContainer;
    sr:TSearchRec;
    st,st2:TStream;
    zs:TpfzlibCompressionStream;
    sfn,tfn:UnicodeString;
    compress:boolean;
  begin
//    if FileExists() then DeleteFile(fn);
//    cf:=T1CContainer.Create(dst,true,false);
    if FindFirst(dir+'*',faAnyFile,sr)=0 then begin
      repeat
       if (LowerCase(sr.Name)<>'.stub') then
        if sr.Attr and faDirectory<>0 then begin
          if recurse and (sr.Name<>'.') and (sr.Name<>'..') then begin
            tfn:=options.fn+'.'+sr.Name+'.container';
            st:=TFileStream.Create(tfn,fmCreate or fmShareDenyWrite);
            cf:=T1CContainer.Create(st,cfClassic,true,false);
            DoPackInt(dir+sr.Name+DirectorySeparator,cf,true,cRaw);
            cf.Free;
            st.Position:=0;
            if usecompress<>cRaw then begin
              sfn:=tfn+'.inflate';
              st2:=TFileStream.Create(sfn,fmCreate or fmShareDenyWrite);
              zs:=TpfzlibCompressionStream.CreateRawDeflate(st2);
              CopyStream(st,zs);
              zs.Free;
              st.Free;
              DeleteFile(tfn);
              tfn:=sfn;
              st2.Position:=0;
              st:=st2;
            end;
            dst.AddFile(sr.Name,st,FileDateToDateTime(sr.Time),FileDateToDateTime(sr.Time));
            st.Free;
            DeleteFile(tfn);
          end;
        end else begin
          write(#$0d,dir+sr.Name,'':20);
          sfn:=sr.Name;
          compress:=usecompress=cDeflate;
          if (usecompress=cAuto) and (LowerCase(copy(sfn,length(sfn)-8+1,8))='.deflate') then begin
            compress:=true;
            sfn:=copy(sfn,1,length(sfn)-8);
          end;
          st:=TFileStream.Create(dir+sr.Name,fmOpenRead or fmShareDenyWrite);
          if compress then begin
            tfn:=dir+sr.Name+'.inflate';
            st2:=TFileStream.Create(tfn,fmCreate or fmShareDenyWrite);
            zs:=TpfzlibCompressionStream.CreateRawDeflate(st2);
            CopyStream(st,zs);
            zs.Free;
            st.Free;
            st2.Position:=0;
            st:=st2;
          end;

          dst.AddFile(sfn,st,FileDateToDateTime(sr.Time),FileDateToDateTime(sr.Time));
          st.Free;
          if compress then DeleteFile(tfn);
        end;
        if FindNext(sr)<>0 then begin
          FindClose(sr);
          break;
        end;
      until false;
    end;
  end;

var
  cf:T1CContainer;
  st:TStream;
begin
  if FileExists(options.fn) then DeleteFile(options.fn);
  cf:=T1CContainer.Create(options.fn,options.useFormat);
  if (cf.FormatVersion=cfNew) then
    if options.nostub then cf.SetStub(nil)
    else begin
      if FileExists(options.dir+'.stub') then begin
        st:=TFileStream.Create(options.dir+'.stub',fmOpenRead or fmShareDenyWrite);
        cf.SetStub(st);
        st.Free;
      end;
    end;
  DoPackInt(options.dir,cf,options.recurse,options.compress);
  cf.Free;
end;

procedure DoList();
var
  cf:T1CContainer;
  r:TContainerDocumentRecord;
  i:integer;
  ds:integer;
  ts:int64;
  regex:TRegExpr;
begin
  if options.fn='' then begin
      writeln('No file specified');
      exit;
  end else if not FileExists(options.fn) then begin
    writeln('File specified does not exist');
    exit;
  end;
  cf:=T1CContainer.Create(options.fn,options.useFormat);
  writeln('Container format: ',IfThen(cf.FormatVersion=cfClassic,'Classic','New'));
  try
    ds:=Length(DateTimeToStr(now));
    ts:=0;
    writeln('Created':ds,' | ','Modified':ds,' | ','Size':10,' | Name');
    if (options.mask<>'') then begin
      regex:=TRegExpr.Create;
      regex.Expression:=options.mask;
    end;
    for i:=0 to cf.DocumentsCount-1 do begin
      r:=cf.Files[i];
      inc(ts,r.Size);
      if (options.mask<>'')and(not regex.Exec(r.Name)) then continue;
      writeln(DateTimeToStr(r.CreationTime),' | ',DateTimeToStr(r.ModificationTime),' | ',r.Size:10,' | ',r.Name);
    end;
    writeln('Total ',cf.DocumentsCount,' files, ',ts,' bytes');
  finally
    cf.Free;
  end;
end;

procedure DoCompare();

  function dcCompareStreams(st1,st2:TStream):boolean;
  var
    buf:array of byte;
    r:integer;
    dc1,dc2:TpfzlibDecompressionStream;
  begin
    st1.Position:=0;
    st2.Position:=0;
    result:=CompareStreams(st1,st2);
    if not result then begin
      SetLength(buf,4096);
      r:=st1.Read(buf[0],Length(Buf));
      if TestBufferCompressed(buf[0],r,-15) then begin
        r:=st2.Read(buf[0],Length(Buf));
        if not TestBufferCompressed(buf[0],r,-15) then exit;
        st1.Position:=0;
        st2.Position:=0;
        dc1:=TpfzlibDecompressionStream.CreateRawDeflate(st1);
        dc2:=TpfzlibDecompressionStream.CreateRawDeflate(st2);
        try
          result:=CompareStreams(dc1,dc2);
        finally
          dc1.Free;
          dc2.Free;
        end;
      end;
    end;
  end;

var
  cf1,cf2:T1CContainer;
  sl1,sl2:TStringList;
  i1,i2,i1c,i2c:integer;
  ws1,ws2:WideString;
  st1,st2:TStream;
  rc:boolean;
  regex:TRegExpr;
begin
  cf1:=T1CContainer.Create(options.fn,options.useFormat);
  cf2:=T1CContainer.Create(options.fn2,options.useFormat);
  i1c:=cf1.DocumentsCount();
  i2c:=cf2.DocumentsCount();
  if i1c<=0 then begin
    if i2c<=0 then begin
      writeln('Both containters empty');
      exit;
    end else begin
      writeln(options.fn,' is empty');
      exit;
    end;
  end;
  if i2c<=0 then begin
    writeln(options.fn2,' is empty');
    exit;
  end;
  sl1:=TStringList.Create;
  sl2:=TStringList.Create;
  cf1.FillFilesList(sl1);
  cf2.FillFilesList(sl2);
  sl1.Sort;
  sl2.Sort;
  i1:=0;
  i2:=0;

  if (options.mask<>'') then begin
    regex:=TRegExpr.Create;
    regex.Expression:=options.mask;
  end;

  repeat
    ws1:=sl1[i1];
    ws2:=sl2[i2];

    if (options.mask<>'')and(not regex.Exec(ws1)) then begin
      inc(i1);
      continue;
    end;
    if (options.mask<>'')and(not regex.Exec(ws2)) then begin
      inc(i2);
      continue;
    end;

    if ws1=ws2 then begin
      st1:=TMemoryStream.Create;
      st2:=TMemoryStream.Create;
      cf1.ReadDocument(cf1.Files[Integer(sl1.Objects[i1])].BlockOffset,st1);
      cf2.ReadDocument(cf2.Files[Integer(sl2.Objects[i2])].BlockOffset,st2);
     try
      rc:=dcCompareStreams(st1,st2);
      writeln(ws1:25,'|',ws2:25,':',IfThen(rc,'equal','different'));
     except
      on e:Exception do
        writeln(ws1:25,'|',ws2:25,':','Exception: ',e.Message);
     end;
      st1.Free;
      st2.Free;
      inc(i1);inc(i2);
    end else if ws1<ws2 then begin
      writeln(ws1:25,'| <missed>');
      inc(i1);
    end else begin
      writeln('<missed>':25,'|',ws2:25);
      inc(i2);
    end;
  until (i1>=i1c)or(i2>=i2c);

  for i1:=i1 to i1c-1 do begin
    if (options.mask<>'')and(not regex.Exec(sl1[i1])) then continue;
    writeln(sl1[i1]:25,'| <missed>');
  end;
  for i2:=i2 to i2c-1 do begin
    if (options.mask<>'')and(not regex.Exec(sl2[i2])) then continue;
    writeln('<missed>':25,'|',sl2[i2]:25);
  end;

end;

procedure DoConvert();
var
  cf1,cf2:T1CContainer;
  i1:integer;
  st1:TStream;
begin
  if options.fn='' then begin
    writeln('No input file specified');
    exit;
  end else if not FileExists(options.fn) then begin
    writeln('File specified does not exist');
    exit;
  end;
  if options.fn2='' then begin
    writeln('No output file specified');
    exit;
  end;

  if FileExists(options.fn2) then DeleteFile(options.fn2);

  cf1:=T1CContainer.Create(options.fn,options.useFormat);

  if options.convertFormat=0 then
    options.convertFormat:=3-cf1.FormatVersion;

  cf2:=T1CContainer.Create(options.fn2,options.convertFormat);
  WriteLn('Source format: ',IfThen(cf1.FormatVersion=1,'Classic','New'));
  WriteLn('Target format: ',IfThen(cf2.FormatVersion=1,'Classic','New'));

  if (cf2.FormatVersion=cfNew) and (options.nostub) then cf2.SetStub(nil);

  for i1:=0 to cf1.DocumentsCount-1 do begin
    st1:=TMemoryStream.Create;
    cf1.ReadDocument(cf1.Files[i1].BlockOffset,st1);
    cf2.AddFile(cf1.Files[i1].Name,st1,
      cf1.Files[i1].CreationTime,
      cf1.Files[i1].ModificationTime
    );
    st1.Free;
    write(#$0d,i1+1,' of ',cf1.DocumentsCount,', ',(i1+1)*100 div cf1.DocumentsCount,'%');
  end;
  writeln;
  writeln('Total documents: ',cf1.DocumentsCount);
  cf1.Free;
  cf2.Free;
end;

procedure DoTest();
var
  cf:T1CContainer;
  st,st2:TStream;
  zds:TpfzlibDecompressionStream;
  i,r:integer;
  buf:array of byte;
  err:boolean;
  decompress:boolean;

begin
  if options.fn='' then begin
      writeln('No file specified');
      exit;
  end else if not FileExists(options.fn) then begin
    writeln('File specified does not exist');
    exit;
  end;
  cf:=T1CContainer.Create(options.fn,options.useFormat);
  try
    for i:=0 to (cf.DocumentsCount-1) do begin
      err:=false;
      if (cf.Files[i].Size<0) or (cf.Files[i].BlockOffset<=0) then begin
        writeln(#$0d+cf.Files[i].Name+'      ');
        writeln('No data');
        continue;
      end;
      st:=TMemoryStream.Create();
     try
      try
        cf.ReadDocument(cf.Files[i].BlockOffset,st);

        decompress:=options.compress=cDeflate;
        if options.compress=cAuto then begin
            st.Seek(0,soBeginning);
            SetLength(buf,4096);
            r:=st.Read(buf[0],Length(buf));
            decompress:=TestBufferCompressed(buf[0],r,-15);
            st.Position:=0;
        end;

        if decompress then begin
            st2:=TpfNullStream.Create();
            st.Seek(0,soBeginning);
            zds:=TpfzlibDecompressionStream.CreateRawDeflate(st);

            try
              CopyStream(zds,st2);
            finally
              st2.Free;
              zds.Free;
            end;
        end;
      finally
        st.Free;
      end;
     except
        on e:Exception do begin
          writeln(#$0d+cf.Files[i].Name+'      ');
          writeln('Exception '+e.Message);
        end;
     end;
      write(#$0d,i+1,' of ',cf.DocumentsCount,', ',(i+1)*100 div cf.DocumentsCount,'%');
    end;
  finally
    cf.Free;
  end;
end;

procedure DoInflate;
var
  st,st2:TStream;
  zds:TpfzlibDecompressionStream;
begin
  st:=TFileStream.Create(options.fn,fmOpenRead or fmShareDenyWrite);
  st2:=TFileStream.Create(options.fn2,fmCreate or fmShareDenyWrite);
  st.Seek(0,soBeginning);
  zds:=TpfzlibDecompressionStream.CreateRawDeflate(st);
  CopyStream(zds,st2);
  zds.Free;
  st2.Free;
  st.Free;
end;

procedure DoDeflate;
var
  st,st2:TStream;
  zcs:TpfzlibCompressionStream;
begin
  st:=TFileStream.Create(options.fn,fmOpenRead or fmShareDenyWrite);
  st2:=TFileStream.Create(options.fn2,fmCreate or fmShareDenyWrite);
  st.Seek(0,soBeginning);
  zcs:=TpfzlibCompressionStream.CreateRawDeflate(st2);
  CopyStream(st,zcs);
  zcs.Free;
  st2.Free;
  st.Free;
end;

type
  TCFUVersion=record
    confName,confAuthor,confVersion,confVersionID:string;
  end;
  TCFUInfo=class
    verCFU:integer;
    version:TCFUVersion;
    upd_from:array of TCFUVersion;
    rootID:string;
    confVersion:string;
    delObjects:TStrings;
    insObjects:TpfStrKeyValues;
    ok:boolean;
    constructor Create(s:RawByteString);
    destructor Destroy;override;
  end;

constructor TCFUInfo.Create(s:RawByteString);
  function GetVerInfo(const a:TpfAnyElement;var i:integer):TCFUVersion;
  begin
    result.confName:=a[i].Value;
    result.confAuthor:=a[i+1].Value;
    result.confVersion:=a[i+2].Value;
    result.confVersionID:=a[i+3].Value;
    inc(i,4);
  end;

var
  us:String;
  i,idx:integer;
  verscnt,delcnt,inscnt:integer;
  a:TpfAnyElement;
begin
  delObjects:=TStringList.Create;
  TStringList(delObjects).sorted:=true;
  insObjects:=TpfStrKeyValues.Create;
  if (length(s)>3) and (s[1]=#$EF) and (s[2]=#$BB) and (s[3]=#$BF) {copy(s,1,3)=#$EF#$BB#$BF} then begin s:=copy(s,4,length(s)); end;
  us:=s;
  i:=2;
  a:=ParseList(us,i);
  verCFU:=StrToInt(a[0].Value);
  verscnt:=StrToInt(a[1].Value);
  SetLength(upd_from,verscnt);
  idx:=2;
  for i:=0 to verscnt-1 do
    upd_from[i]:=GetVerInfo(a,idx);
  delcnt:=StrToInt(a[idx].Value);
  inc(idx);
  for i:=0 to delcnt-1 do begin
    delObjects.Add(a[idx].Value);
    inc(idx);
  end;
  inscnt:=StrToInt(a[idx].Value);
  inc(idx);
  for i:=0 to inscnt-1 do begin
    insObjects.Values[a[idx].Value]:=a[idx+1].Value;
    inc(idx,2);
  end;
  version:=GetVerInfo(a,idx);
  confVersion:=a[idx].ToString;
  inc(idx);
  rootID:=a[idx].ToString;
  inc(idx);
  ok:=idx>=a.ValuesList.Count;
  a.Free;
end;

destructor TCFUInfo.Destroy;
begin
  delObjects.Free;
  insObjects.Free;
end;

procedure DoCFUInfo;
var
  st,st2:TStream;
  zds:TpfzlibDecompressionStream;
  cf:T1CContainer;
  info:TCFUInfo;
  sl:TStrings;
  i:integer;
  rs:AnsiString;
begin
  if options.fn='' then begin
      writeln('No file specified');
      exit;
  end else if not FileExists(options.fn) then begin
    writeln('File specified does not exist');
    exit;
  end;
  st:=TFileStream.Create(options.fn,fmOpenRead or fmShareDenyWrite);
  st2:=TpfTempFileStream.Create();
  st.Seek(0,soBeginning);
  zds:=TpfzlibDecompressionStream.CreateRawDeflate(st);
  CopyStream(zds,st2);
  zds.Free;
  st.Free;
  try
    st2.Position:=0;
    cf:=T1CContainer.Create(st2,options.useFormat);
    sl:=TStringList.Create;
    try
      TStringList(sl).Sorted:=true;
      cf.FillFilesList(sl);
      i:=sl.IndexOf('UpdateInfo.inf');
      if i<0 then begin
        writeln('Bad CFU');
        exit;
      end;
      i:=Integer(sl.Objects[i]);
      st:=TpfTempFileStream.Create();
      try
        cf.ReadDocument(cf.Files[i].BlockOffset,st);
        st.Position:=0;
        SetLength(rs,st.Size);
        st.Read(rs[1],Length(rs));
        SetCodePage(RawByteString(rs),CP_UTF8,false);
        info:=TCFUInfo.Create(rs);

        writeln('Conf   : ',info.version.confName);
        writeln('Author : ',info.version.confAuthor);
        writeln('Version: ',info.version.confVersion);
        writeln('Delete : ',info.delObjects.Count);
        writeln('Insert : ',info.insObjects.Count);
        writeln('Root   : ',info.RootID);
        writeln('ReleaseID  : ',info.insObjects.Values[''],' ',info.version.confVersionID);
        writeln('Updates for:');
        for i:=0 to Length(info.upd_from)-1 do
          writeln((i+1):2,' ',info.upd_from[i].confName,' ',info.upd_from[i].confVersion,' ',info.upd_from[i].confVersionId);
        info.Free;
      finally
        st.Free;
      end;
    finally
      sl.Free;
      cf.Free;
    end;
  finally
    st2.Free;
  end;
end;

function GenGuid():string;
begin
  result:=lowercase(IntToHex(random($FFFFFFFF),8)
    +'-'+IntToHex(random($FFFF),4)+'-'+IntToHex(random($FFFF),4)
    +'-'+IntToHex(random($FFFF),4)+'-'
    +IntToHex(random($FFFF),4)+IntToHex(random($FFFF),4)+IntToHex(random($FFFF),4));
end;

procedure ParseVersions(s:RawByteString;sl:TpfStrKeyValues);
var
  us:String;
  i:integer;
  ver,cnt:integer;
  a:TpfAnyElement;
begin
  if (length(s)>3) and (s[1]=#$EF) and (s[2]=#$BB) and (s[3]=#$BF) {copy(s,1,3)=#$EF#$BB#$BF} then begin s:=copy(s,4,length(s)); end;
  us:=s;
  i:=2;
  a:=ParseList(us,i);
  sl.Clear;
  ver:=StrToInt(a[0].Value);
  cnt:=StrToInt(a[1].Value);
  for i:=0 to cnt-1 do
    sl.Values[a[1+ver+i*2].Value]:=a[1+ver+i*2+1].Value;
  a.Free;
end;

procedure pfConcat(var target:RawByteString;const s1:RawByteString='';const s2:RawByteString='';const s3:RawByteString='');
var
  ts:RawByteString;
  i:integer;
begin
  ts:=s1;
  if ts<>'' then begin
    i:=Length(target);
    SetLength(target,i+length(ts));
    move(ts[1],target[i+1],length(ts));
  end;
  ts:=s2;
  if ts<>'' then begin
    i:=Length(target);
    SetLength(target,i+length(ts));
    move(ts[1],target[i+1],length(ts));
  end;
  ts:=s3;
  if ts<>'' then begin
    i:=Length(target);
    SetLength(target,i+length(ts));
    move(ts[1],target[i+1],length(ts));
  end;
end;

procedure DoCFUpdate;
var
  st,st2,st_u:TStream;
  zds:TpfzlibDecompressionStream;
  zcs:TpfzlibCompressionStream;
  cfu,cf_in,cf_out:T1CContainer;
  info:TCFUInfo;
  sl_cfu,sl_cf,sl_target:TStrings;
  sl_oldvers:TpfStrKeyValues;
  i,fi:integer;
  rs,rs2:RawByteString;
  cfReleaseID:string;
  ReleaseCheck:boolean;
  NewVersions,NewRoot:RawByteString;
  s:String;
  i1,i2:integer;
  statUpd,statDel:integer;
//t1,t2:TDateTime;
begin
  NewRoot:='';
//0. Open source CF
  if options.fn='' then begin
      writeln('No source file specified');
      exit;
  end else if not FileExists(options.fn) then begin
    writeln('Source file specified does not exist');
    exit;
  end;
  if options.fn3='' then begin
      writeln('No target file specified');
      exit;
  end else if FileExists(options.fn3) then begin
    DeleteFile(options.fn3);
    if FileExists(options.fn3) then begin
      writeln('Can not delete target file');
      exit;
    end;
  end;
  cf_in:=T1CContainer.Create(options.fn,options.useFormat);
//1. unpack CFU
  st:=TFileStream.Create(options.fn2,fmOpenRead or fmShareDenyWrite);
  st_u:=TpfTempFileStream.Create();
  st.Seek(0,soBeginning);
  zds:=TpfzlibDecompressionStream.CreateRawDeflate(st);
  CopyStream(zds,st_u);
  zds.Free;
  st.Free;
  try
//3 Get versions from CF
    sl_cf:=TStringList.Create;
    TStringList(sl_cf).Sorted:=true;
    cf_in.FillFilesList(sl_cf);
    sl_oldvers:=TpfStrKeyValues.Create;
    i:=sl_cf.IndexOf('versions');
    if i<0 then begin
      writeln('Bad CF, no "versions" file, use --force option');
//      exit;
    end else begin
      i:=Integer(sl_cf.Objects[i]);
      st:=TpfTempFileStream.Create();
      cf_in.ReadDocument(cf_in.Files[i].BlockOffset,st);
      st.Position:=0;
      SetLength(rs,st.Size);
      st.Read(rs[1],Length(rs));
      FreeAndNil(st);
      if TestBufferCompressed(rs[1],length(rs),-15) then begin
        st:=TStringStream.Create(rs);
        st2:=TMemoryStream.Create();
        zds:=TpfzlibDecompressionStream.CreateRawDeflate(st);
        CopyStream(zds,st2);
        zds.Free;

        SetLength(rs,st2.Size);
        st2.Position:=0;
        st2.Read(rs[1],st2.Size);
  //      rs:=TStringStream(st2).DataString;
        st.Free;
        st2.Free;
      end;
      SetCodePage(RawByteString(rs),CP_UTF8,false);
      ParseVersions(rs,sl_oldvers);
    end;
    cfReleaseID:=sl_oldvers.Values[''];
//4. Open CFU
    st_u.Position:=0;
    cfu:=T1CContainer.Create(st_u);
    sl_cfu:=TStringList.Create;
    try
//Get UpdateInfo.inf file
      TStringList(sl_cfu).Sorted:=true;
      cfu.FillFilesList(sl_cfu);
      i:=sl_cfu.IndexOf('UpdateInfo.inf');
      if i<0 then begin
        writeln('Bad CFU');
        exit;
      end;
      i:=Integer(sl_cfu.Objects[i]);
      st:=TpfTempFileStream.Create();
      cfu.ReadDocument(cfu.Files[i].BlockOffset,st);
//Get CFU metadata from UpdateInfo.inf
      st.Position:=0;
      SetLength(rs,st.Size);
      st.Read(rs[1],Length(rs));
      FreeAndNil(st);
      SetCodePage(RawByteString(rs),CP_UTF8,false);
      info:=TCFUInfo.Create(rs);
      try
//Check CF ReleaseID
        if (not options.force) and (cfReleaseID<>'') then begin
          ReleaseCheck:=false;
          for i:=0 to Length(info.upd_from)-1 do
            if info.upd_from[i].confVersionId=cfReleaseID then begin
              ReleaseCheck:=true;
              break;
            end;
          if not ReleaseCheck then begin
            writeln('Can not match versions CFU and CF');
            exit;
          end;
        end;
//5.start creating new CF
        if options.convertFormat=0 then
          options.convertFormat:=cf_in.FormatVersion;

        cf_out:=T1CContainer.Create(options.fn3,options.convertFormat);

        statDel:=0;
        statUpd:=0;

        writeln('Moving data');

        sl_target:=TStringList.Create;
        for fi:=0 to sl_cf.Count-1 do begin
          s:=lowercase(sl_cf[fi]);
          if (s='version')or(s='versions')or(s='root') then continue;
          if sl_cfu.IndexOf(s)>=0 then begin //skip - new object, already moved
            inc(statUpd);
            continue;
          end else if info.delObjects.IndexOf(s)>=0 then begin //skip this object, deleted
            inc(statDel);
            continue;
          end;

          sl_target.AddObject(sl_cf[fi],Pointer(1));
        end;
        for fi:=0 to sl_cfu.Count-1 do begin
          s:=(sl_cfu[fi]);
          if (lowercase(s)='updateinfo.inf') then continue;
          sl_target.AddObject(s,Pointer(2));
        end;
//root
//Read old "root" and update it
        NewRoot:='';
        st:=TMemoryStream.Create();
        i:=sl_cf.IndexOf('root');
        if i>=0 then begin
          i:=Integer(sl_cf.Objects[i]);
          cf_in.ReadDocument(cf_in.Files[i].BlockOffset,st); //read old "root"
          st.Position:=0;
          SetLength(rs,st.Size);
          st.Read(rs[1],Length(rs));
          st.Free;
          if (length(rs)>0)and TestBufferCompressed(rs[1],length(rs),-15) then begin //decompress if compressed
            st:=TStringStream.Create(rs);
            st2:=TStringStream.Create('');
            zds:=TpfzlibDecompressionStream.CreateRawDeflate(st);
            CopyStream(zds,st2);
            zds.Free;
            rs:=TStringStream(st2).DataString;
            st.Free;
            st2.Free;
          end;
          //try patching old "root"
          i1:=Pos(',',rs);
          i2:=PosEx(',',rs,i1+1);
          if i2=0 then i2:=Pos('}',rs);
          if (i1<=0)or(i2<=0) then begin //recreate it later
          end else begin
            NewRoot:=copy(rs,1,i1);
            rs2:=Info.RootID;
            pfConcat(NewRoot,rs2,Copy(rs,i2,Length(rs)));
          end;
        end;

        if NewRoot='' then begin //recreate new root
          NewRoot:=#$EF#$BB#$BF'{2,';
          rs:=Info.RootID;
          pfConcat(NewRoot,rs,',}');
        end;

        sl_target.AddObject('root',TStringStream.Create(NewRoot));

//version
        rs:=#$EF#$BB#$BF'{'#13#10;
        rs2:=info.confVersion;
        pfConcat(rs,rs2,#13#10'}');
        sl_target.AddObject('version',TStringStream.Create(rs));

//versions
        i:=sl_target.Add('versions');
        NewVersions:=#$EF#$BB#$BF'{1,';
        pfConcat(NewVersions,IntToStr(sl_target.Count+1),',"",',info.insObjects.Values['']);
        for fi:=0 to sl_target.Count-1 do begin
          rs:=sl_target[fi];
          pfConcat(NewVersions,',"',rs,'",');
          if (rs='root')or(rs='version')or(rs='versions') then
            rs:=''
          else begin
            rs:=info.insObjects.Values[rs];
            if rs='' then rs:=sl_oldvers.Values[rs];
          end;
          if rs='' then begin rs:=GenGuid(); {writeln('gen for ',rs);} end;

          pfConcat(NewVersions,rs);
        end;
        pfConcat(NewVersions,'}');

        sl_target.Objects[i]:=TStringStream.Create(NewVersions);

// Move data
        TStringList(sl_target).Sorted:=true;
        for fi:=0 to sl_target.Count-1 do begin
          write(#$0d,fi+1,' of ',sl_target.Count,', ',(fi+1)*100 div sl_target.Count,'%');
          s:=sl_target[fi];
          if sl_target.Objects[fi]=Pointer(1) then begin // From CF
            i:=sl_cf.IndexOf(s);
            i:=Integer(sl_cf.Objects[i]);
            if cf_in.Files[i].Size<=MaxStreamSizeForMemStream then
              st:=TMemoryStream.Create()
            else
              st:=TpfTempFileStream.Create();
            cf_in.ReadDocument(cf_in.Files[i].BlockOffset,st);
            st.Position:=0;
            cf_out.AddFile(cf_in.Files[i].Name,st,cf_in.Files[i].CreationTime,cf_in.Files[i].ModificationTime);
            st.Free;
          end else if sl_target.Objects[fi]=Pointer(2) then begin //From CFU with compression
            i:=sl_cfu.IndexOf(s);
            i:=Integer(sl_cfu.Objects[i]);
            if cfu.Files[i].Size<=MaxStreamSizeForMemStream then
              st:=TMemoryStream.Create()
            else
              st:=TpfTempFileStream.Create();
            zcs:=TpfzlibCompressionStream.CreateRawDeflate(st);
            cfu.ReadDocument(cfu.Files[i].BlockOffset,zcs);
            zcs.Free;
            st.Position:=0;
            cf_out.AddFile(cfu.Files[i].Name,st,cfu.Files[i].CreationTime,cfu.Files[i].ModificationTime);
            st.Free;
          end else begin //special files
            st:=TMemoryStream.Create();
            zcs:=TpfzlibCompressionStream.CreateRawDeflate(st);
            CopyStream(sl_target.Objects[fi] as TStream,zcs);
            zcs.Free;
            st.Position:=0;
            cf_out.AddFile(s,st,now(),now());
            st.Free;
            sl_target.Objects[fi].Free;
            sl_target.Objects[fi]:=nil;
          end;
        end;

        writeln;
        writeln('Updated, new objects count=',cf_out.DocumentsCount);
        writeln('Added  : ',sl_cfu.Count-1-statUpd);
        writeln('Updated: ',statUpd);
        writeln('Deleted: ',statDel);

        cf_out.Free;
      finally
        info.Free;
      end;

    finally
      sl_cfu.Free;
      cfu.Free;
    end;
  finally
    st_u.Free;
    cf_in.Free;
    sl_cf.Free;
    sl_oldvers.Free;
  end;
end;

{var
  cf:T1CContainer;
  st1:TStream;
  s,s1:RawByteString;
begin
//  st1:=TFileStream.Create('D:\PashaProg\pf1CTools\pfCFTools\samples\TestSamples.bin',fmCreate);
  st1:=TFileStream.Create('TestStr.bin',fmCreate);
  s:=#$EF#$BB#$BF'{'#13#10;
  st1.Write(s[1],length(s));
  s1:=fixStrEnc(IntToStr(1));
writeln(length(s),' ',length(s1),' ',length(s+s1));
  s:=#$EF#$BB#$BF'{'+s1;
  st1.Write(s[1],length(s));
  st1.Free;
  exit;

  cf:=T1CContainer.Create('D:\PashaProg\pf1CTools\pfCFTools\samples\1Cv8-test-8-3-20.cf');
//  writeln(IntToHex(cf.GetContainerV1Size(),8));
  writeln(cf.FormatVersion);
end.
//}

begin
  randomize;
  ParseParameters;
  case options.action of
    aHelp:
      ShowHelp();
    aUnpack:
      DoUnpack();
    aList:
      DoList();
    aCompare:
      DoCompare();
    aPack:
      DoPack();
    aConvert:
      DoConvert();
    aTest:
      DoTest();
    aInflate:
      DoInflate();
    aDeflate:
      DoDeflate();
    aCFUInfo:
      DoCFUInfo();
    aCFUpdate:
      DoCFUpdate();
  else
    writeln('Internal error: unknown action');
  end;
end.

{
var
  fs,fs2:TFileStream;
  zs,zs2:TpfzlibDecompressionStream;
  buf:array of byte;
  r:integer;
const BufSize=1024*1024;
begin
  fs:=TFileStream.Create('ssd2',fmOpenRead or fmShareDenyWrite);
  fs2:=TFileStream.Create('03a20bf0-5243-471c-97b4-1dd81b441d97.0',fmOpenRead or fmShareDenyWrite);
  zs:=TpfzlibDecompressionStream.CreateGZ(fs);
  zs2:=TpfzlibDecompressionStream.CreateRawDeflate(fs2);
  writeln(CompareStreams(zs,zs2));exit;
end.
}
