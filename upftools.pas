unit upfTools;

{$mode delphiunicode}{$H+}

interface

uses
  Classes, {$IFDEF WINDOWS}Windows{$ELSE}Unix{$ENDIF}, SysUtils, zlib;
//,zstream;

type

  { TpfzlibCustomStream }

  TpfzlibCustomStream=class(TOwnerStream)
    protected
      Fz_stream:z_stream;
      FBuffer:array of byte;
      function GetPosition() : Int64; override;
    public
      constructor Create(ASource:TStream);
  end;

  { TpfzlibDecompressionStream }

  TpfzlibDecompressionStream=class(TpfzlibCustomStream)
  public
    constructor Create(ASource:TStream);overload;
    constructor CreateRawDeflate(ASource:TStream);
    constructor CreateGZ(ASource:TStream);
    constructor Create(ASource:TStream;winbits:integer);overload;
    constructor Create(ASource:TStream;const zs:z_stream);overload;
    destructor Destroy;override;
    function Read(var Buffer; Count: Longint): Longint; override;
  end;

  { TpfzlibCompressionStream }

  TpfzlibCompressionStream=class(TpfzlibCustomStream)
  public
    constructor Create(ASource:TStream;ALevel:integer=Z_DEFAULT_COMPRESSION);overload;
    constructor CreateRawDeflate(ASource:TStream;ALevel:integer=Z_DEFAULT_COMPRESSION);
    constructor CreateGZ(ASource:TStream;ALevel:integer=Z_DEFAULT_COMPRESSION);
    constructor Create(ASource:TStream;ALevel:integer;winbits:integer);overload;
    constructor Create(ASource:TStream;const zs:z_stream);overload;
    destructor Destroy;override;
    function Write(const Buffer; Count: Longint): Longint; override;
    procedure Flush;
  end;

  TpfzlibException=class(exception);

  { TPFTempFileStream }

  TpfTempFileStream=class(THandleStream)
  protected
    FFileName:WideString;
  public
    constructor Create();overload;
    constructor Create(fn:WideString);overload;
    destructor Destroy;override;
    property FileName:WideString read FFileName;
  end;

  TpfNullStream=class(TStream)
  public
    constructor Create();
    destructor Destroy;override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Read(var Buffer; Count: Longint): Longint; override;
  end;

  TpfStrValue=class
    Value:string;
    constructor Create(_value:string);
  end;

  TpfStrKeyValues=class
  protected
    strings:TStringList;
    procedure SetValue(const Name, Value: string);
    function GetValue(const Name: string): string;
  public
    constructor Create();
    destructor Destroy();override;
    procedure Clear();
    property Values[const Name: string]: string read GetValue write SetValue;default;
    function Count:integer;
  end;

function TestBufferCompressed(const buf;bufsize:integer;out zs:z_stream; winbits:integer=15):boolean;overload;
function TestBufferCompressed(const buf;bufsize:integer;winbits:integer=15):boolean;overload;

function CompareStreams(st1,st2:TStream):boolean;
procedure CopyStream(ASource,ADest:TStream);

implementation

const ZlibBufSize=512*1024;

function TpfStrKeyValues.Count():integer;
begin
  result:=strings.Count;
end;

procedure TpfStrKeyValues.Clear();
begin
  strings.Clear;
end;

procedure TpfStrKeyValues.SetValue(const Name, Value: string);
var
  i:integer;
begin
  i:=strings.IndexOf(Name);
  if i<0 then i:=strings.Add(Name);
  strings.Objects[i]:=TpfStrValue.Create(Value);
end;

function TpfStrKeyValues.GetValue(const Name: string): string;
var
  i:integer;
begin
  if not strings.Find(Name,i) then begin
    Result:='';
  end else begin
    Result:=(strings.Objects[i] as TpfStrValue).Value;
  end;
end;

constructor TpfStrKeyValues.Create();
begin
  strings:=TStringList.Create;
  strings.Sorted:=true;
  strings.CaseSensitive:=false;
  strings.OwnsObjects:=true;
end;

destructor TpfStrKeyValues.Destroy();
begin
  strings.Free;
end;

constructor TpfStrValue.Create(_value:string);
begin
  Value:=_value;
end;

{ TpfNullStream }

constructor TpfNullStream.Create();
begin
end;

destructor TpfNullStream.Destroy;
begin
  inherited;
end;

function TpfNullStream.Write(const Buffer; Count: Longint): Longint; 
begin
  result:=Count;
end;

function TpfNullStream.Read(var Buffer; Count: Longint): Longint; 
begin
  result:=0;
end;

{ TPFTempFileStream }

constructor TpfTempFileStream.Create();
var
  root:WideString;
  i:integer;
begin
{$IFDEF WINDOWS}
  root:=GetEnvironmentVariable('TEMP');
  if root='' then
    root:=GetEnvironmentVariable('TMP');
{$ELSE}
  root:='/tmp/';
{$ENDIF}
  if root='' then
    root:=ExtractFilePath(ParamStr(0));
  if (root<>'')and(root[length(root)]<>DirectorySeparator) then
    root:=root+DirectorySeparator;
  i:=0;
  root:=root+IntToStr(Random(1000))+'-';
  repeat
    if FileExists(root+IntToStr(i)+'.tmp') then begin
      inc(i);
      continue;
    end;
    root:=root+IntToStr(i)+'.tmp';
    Create(root);
    break;
  until false;
end;

constructor TpfTempFileStream.Create(fn: WideString);
var
  h:THandle;
begin
{$IFDEF WINDOWS}
  h:=CreateFileW(PWideChar(fn),GENERIC_READ or GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_DELETE,nil,CREATE_NEW,
    FILE_ATTRIBUTE_TEMPORARY or FILE_FLAG_DELETE_ON_CLOSE,0);
  if h=INVALID_HANDLE_VALUE then
    Raise Exception.Create('Can not create temp file "'+fn+'" error='+IntToStr(GetLastError));
{$ELSE}
  h:=FileCreate(fn);
  DeleteFile(fn);
{$ENDIF}
  FFileName:=fn;
  inherited Create(h);
end;

destructor TpfTempFileStream.Destroy;
begin
  inherited;
{$IFDEF WINDOWS}
  CloseHandle(Handle);
{$ELSE}
  FileClose(Handle);
{$ENDIF}
end;

{ TpfzlibCompressionStream }

constructor TpfzlibCompressionStream.Create(ASource:TStream;ALevel:integer=Z_DEFAULT_COMPRESSION);
begin
  Create(ASource,ALevel,15);
end;

constructor TpfzlibCompressionStream.CreateRawDeflate(ASource: TStream;
  ALevel: integer);
begin
  Create(ASource,ALevel,-15);
end;

constructor TpfzlibCompressionStream.CreateGZ(ASource: TStream; ALevel: integer
  );
begin
  Create(ASource,ALevel,15+16);
end;

constructor TpfzlibCompressionStream.Create(ASource:TStream;ALevel:integer;winbits:integer);
begin
  Inherited Create(ASource);
  if deflateInit2(Fz_stream,ALevel,Z_DEFLATED,winbits,8,Z_DEFAULT_STRATEGY)<>Z_OK then
    Raise TpfzlibException.Create(PAnsiChar(Fz_stream.msg));
  Fz_stream.next_out:=@FBuffer[0];
  Fz_stream.avail_out:=Length(FBuffer);
end;

constructor TpfzlibCompressionStream.Create(ASource: TStream; const zs: z_stream);
begin
  inherited Create(ASource);
  Fz_stream:=zs;

  Fz_stream.next_out:=@FBuffer[0];
  Fz_stream.avail_out:=Length(FBuffer);

  if Fz_stream.avail_in>0 then
    Write(Fz_stream.next_in^,Fz_stream.avail_in);
end;

destructor TpfzlibCompressionStream.Destroy;
var
  r:integer;
begin
  repeat
    r:=deflate(Fz_stream,Z_FINISH);
    if r=Z_STREAM_END then break;
    if (r<>Z_OK)and(r<>Z_BUF_ERROR) then
      Raise TpfzlibException.Create(PAnsiChar(Fz_stream.msg));
    Flush;
  until false;
  Flush;
  deflateEnd(Fz_stream);
  inherited Destroy;
end;

function TpfzlibCompressionStream.Write(const Buffer; Count: Longint): Longint;
var
  r:integer;
begin
  Fz_stream.next_in:=@Buffer;
  Fz_stream.avail_in:=Count;
  repeat
    if Fz_stream.avail_in=0 then break;
    if Fz_stream.avail_out=0 then begin
      Flush;
    end;
    r:=deflate(Fz_stream,Z_NO_FLUSH);
    if (r=Z_OK)or(r=Z_BUF_ERROR) then continue;
    Raise TpfzlibException.Create(PAnsiChar(Fz_stream.msg));
  until false;
  Result:=Count-Fz_stream.avail_in;
end;

procedure TpfzlibCompressionStream.Flush;
var
  r,rp,bs:integer;
begin
  rp:=0;
  bs:=Length(FBuffer)-Fz_stream.avail_out;
  repeat
    r:=Source.Write(FBuffer[rp],bs-rp);
    inc(rp,r);
  until rp>=bs;
  Fz_stream.next_out:=@FBuffer[0];
  Fz_stream.avail_out:=Length(FBuffer);
end;

{ TpfzlibDecompressionStream }

function TpfzlibCustomStream.GetPosition(): Int64;
begin
  Result:=Fz_stream.total_out;
end;

constructor TpfzlibDecompressionStream.Create(ASource: TStream);
begin
  Create(ASource,15);
end;

constructor TpfzlibDecompressionStream.CreateRawDeflate(ASource: TStream);
begin
  Create(ASource,-15);
end;

constructor TpfzlibDecompressionStream.CreateGZ(ASource: TStream);
begin
  Create(ASource,15+16);
end;

constructor TpfzlibDecompressionStream.Create(ASource: TStream; winbits: integer);
begin
  Inherited Create(ASource);
  if inflateInit2(Fz_stream,winbits)<>Z_OK then
    Raise TpfzlibException.Create(PAnsiChar(Fz_stream.msg));
end;

constructor TpfzlibDecompressionStream.Create(ASource: TStream;
  const zs: z_stream);
begin
  inherited Create(ASource);
  Fz_stream:=zs;
  if Fz_stream.avail_in>Length(FBuffer) then SetLength(FBuffer,Fz_stream.avail_in);
  Move(Fz_stream.next_in^,FBuffer[0],Fz_stream.avail_in);
  Fz_stream.next_in:=@FBuffer[0];
end;

destructor TpfzlibDecompressionStream.Destroy;
begin
  inflateEnd(Fz_stream);
  inherited Destroy;
end;

function TpfzlibDecompressionStream.Read(var Buffer; Count: Longint): Longint;
var
  r,lr:integer;
begin
  Fz_stream.next_out:=@Buffer;
  Fz_stream.avail_out:=Count;
  lr:=0;
  repeat
    if Fz_stream.avail_out=0 then break;
    if Fz_stream.avail_in=0 then begin
      Fz_stream.next_in:=@FBuffer[0];
      Fz_stream.avail_in:=Source.Read(FBuffer[0],Length(FBuffer));
      if (Fz_stream.avail_in=0)and(lr=Z_BUF_ERROR) then break;
    end;
    r:=inflate(Fz_stream,Z_SYNC_FLUSH);
    lr:=r;
    if r=Z_STREAM_END then break;
    if (r=Z_OK)or(r=Z_BUF_ERROR) then continue;
    Raise TpfzlibException.Create(PAnsiChar(Fz_stream.msg));
  until false;
  Result:=Count-Fz_stream.avail_out;
end;

{ TpfzlibCustomStream }

constructor TpfzlibCustomStream.Create(ASource:TStream);
begin
  inherited Create(ASource);
  FillChar(Fz_stream,SizeOf(Fz_stream),0);
  SetLength(FBuffer,ZlibBufSize);
end;

function CompareStreams(st1,st2:TStream):boolean;
var
  z1,z2:int64;
  r1,r2,r:integer;
  buf1,buf2:array of byte;
begin
  Result:=false;
  try
    z1:=st1.Size;
  except
    z1:=-1;
  end;
  try
    z2:=st2.Size;
  except
    z2:=-1;
  end;
  if (z1>=0)and(z2>=0) then begin
    if z1<>z2 then exit;
  end;
  SetLength(buf1,ZlibBufSize);
  SetLength(buf2,ZlibBufSize);
  repeat
    r1:=st1.Read(buf1[0],ZlibBufSize);
    if r1<=0 then begin
      if st2.Read(Buf2[0],1)>0 then exit else break;
    end;
    r2:=0;
    repeat
      r:=st2.Read(buf2[r2],r1-r2);
      if r<=0 then exit;
      inc(r2,r);
    until r2=r1;
    if not CompareMem(@Buf1[0],@Buf2[0],r1) then exit;
  until false;
  Result:=true;
end;

function TestBufferCompressed(const buf;bufsize:integer;out zs:z_stream; winbits:integer=15):boolean;overload;
var
  r:integer;
  bufout:array of byte;
begin
  FillChar(zs,SizeOf(zs),0);
  zs.next_in:=@buf;
  zs.avail_in:=bufsize;
  SetLength(bufout,1024);
  zs.next_out:=@bufout[0];
  zs.avail_out:=1024;

  r:=inflateInit2(zs,winbits);
  result:=r=Z_OK;
  if not result then begin
    inflateEnd(zs);
    exit;
  end;

  r:=inflate(zs,Z_SYNC_FLUSH);
  if r=Z_STREAM_END then exit;
  if (r=Z_OK)or(r=Z_BUF_ERROR) then exit;

  result:=false;
  if not result then inflateEnd(zs);
end;

function TestBufferCompressed(const buf;bufsize:integer;winbits:integer=15):boolean;overload;
var
  zs:z_stream;
begin
  result:=TestBufferCompressed(buf,bufsize,zs,winbits);
  if result then inflateEnd(zs);
end;

procedure CopyStream(ASource,ADest:TStream);
var
  buf:array of byte;
  r:integer;
  BufSize:integer;
begin
  BufSize:=ZlibBufSize;
  SetLength(buf,BufSize);

  repeat
     r:=ASource.Read(buf[0],BufSize);
     ADest.Write(buf[0],r);
  until r<=0;
end;

end.

