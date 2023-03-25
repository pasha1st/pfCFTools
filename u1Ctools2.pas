{$IFDEF FPC}{$mode delphiunicode}{$ENDIF}
unit u1Ctools2;

interface
uses classes,SysUtils,contnrs;

const
  cfAuto=0;
  cfClassic=1;
  cfNew=2;

  DefaultCatalogBlockSizeV2=$1000;
  MaxChunkSizeV1=$1000;
  MaxChunkSizeV2=$10000;

type
  TBigSet=class
    FData:array of Cardinal;
    FMaxVal:integer;
    constructor Create(maxval:integer);
    function GetBit(idx:integer):boolean;
    function TestAndSetBit(idx:integer;value:boolean):boolean;
    procedure SetBit(idx:integer;value:boolean);
    property bits[idx:integer]:boolean read GetBit write SetBit;default;
  end;

  TpfElementType=(etList,etString,etNumeric,etGuid,etNull,etOther);
//  TListElementArrayDumb=array of integer;

{  TpfListElement=record
    _type:TpfElementType;
    valueStr:String;
    valueList:TListElementArrayDumb;
    function valueListLength():integer;
    function valueListGet(idx:integer):TpfListElement;
    procedure valueListSet(idx:integer;value:TpfListElement);
    procedure valueListAdd(value:TpfListElement);
  end;
  TpfListElementArray=array of TpfListElement;}

  TpfAnyElement=class
    _type:TpfElementType;
    Value:string;
    ValuesList:TObjectList;
    Constructor Create(tp:TpfElementType;_value:string='');                     //-
    Destructor Destroy;override;                                                //-
    procedure ValueAdd(element:TpfAnyElement);overload;                         //-
    procedure ValueAdd(tp:TpfElementType;_value:string='');overload;            //-
    function ToString:string;                                                   //-
    function GetElement(index:integer):TpfAnyElement;                           //-
    property Values[idx:integer]:TpfAnyElement read GetElement;default;         //-
  end;

  P1CContainerHeader=^T1CContainerHeader;
  T1CContainerHeader=packed record
    FreeBlockOffset:Integer;
    DefaultBlockSize:integer;
    ContainerVersion:integer;
    reserved:integer;
  end;

  P1CContainerHeader_v2=^T1CContainerHeader_v2;
  T1CContainerHeader_v2=packed record
    FreeBlockOffset:Int64;
    DefaultBlockSize:integer;
    ContainerVersion:integer;
    reserved:integer;
  end;

  P1CContainerDocAttributesRec=^T1CContainerDocAttributesRec;
  T1CContainerDocAttributesRecAttrsOnly=packed record
    DocCreationTime:Int64;
    DocModificationTime:int64;
    reserved:integer;
  end;
  T1CContainerDocAttributesRec=record
    DocCreationTime:Int64;
    DocModificationTime:int64;
    reserved:integer;
    FileName:array[0..65535] of WideChar;
  end;

  P1CContainerEntryRec=^T1CContainerEntryRec;
  T1CContainerEntryRec=record
    OffsetAttrs:Int32;
    OffsetData:Int32;
    reserved:integer;
  end;

  P1CContainerEntryRec_v2=^T1CContainerEntryRec_v2;
  T1CContainerEntryRec_v2=record
    OffsetAttrs:int64;
    OffsetData:int64;
    reserved:int64;
  end;

  THexInteger=array[0..7] of AnsiChar;
  THexInteger64=array[0..15] of AnsiChar;

  P1CContainerBlockHeaderRec=^T1CContainerBlockHeaderRec;
  T1CContainerBlockHeaderRec=packed record
    crlf1:array[0..1] of AnsiChar;
    DocumentSize:THexInteger;
    space1:AnsiChar;
    BlockSize:THexInteger;
    space2:AnsiChar;
    NextBlockOffset:THexInteger;
    space3:AnsiChar;
    crlf2:array[0..1] of AnsiChar;
    procedure Init(_DocSize,_BlockSize,_NextBlock:integer);
    procedure SetNextBlock(_NextBlock:integer);
    procedure SetDocSize(_DocSize:integer);
  end;

  P1CContainerBlockHeaderRec_v2=^T1CContainerBlockHeaderRec_v2;
  T1CContainerBlockHeaderRec_v2=packed record
    crlf1:array[0..1] of AnsiChar;
    DocumentSize:THexInteger64;
    space1:AnsiChar;
    BlockSize:THexInteger64;
    space2:AnsiChar;
    NextBlockOffset:THexInteger64;
    space3:AnsiChar;
    crlf2:array[0..1] of AnsiChar;
    procedure Init(_DocSize,_BlockSize,_NextBlock:int64);
    procedure SetNextBlock(_NextBlock:int64);
    procedure SetDocSize(_DocSize:int64);
  end;

  TContainerDocumentRecord=record
    BlockOffset:int64;
    Name:WideString;
    CreationTime,ModificationTime:TDateTime;
    Size:int64;
  end;

  { T1CContainer }

  T1CContainer=class
  protected
    FStream:TStream;
    FModified:boolean;
    FFilesList:array of TContainerDocumentRecord;
    FOwnStream:boolean;
    FLastCatalogBlock:UInt32;
    FLastCatalogBlockFill:integer;
    FLastCatalogBlockSize:integer;
    FLastCatalogBlock_v2:int64;
    FLastCatalogBlockFill_v2:int64;
    FLastCatalogBlockSize_v2:int64;
    FFormatVersion:integer;
    Fv1Stub:array of byte;
    Fv1StubSize:integer;

    FLastBlockOffset:int64;
    FLastBlockSize:int64;

    Header:T1CContainerHeader;
    Header_v2:T1CContainerHeader_v2;

    FDefaultBlockSize:integer;

    function ReadBlock(offset:UInt32;out BlockHeader:T1CContainerBlockHeaderRec;ReadData:boolean=true):AnsiString;
    function ReadBlock_v2(offset:int64;out BlockHeader:T1CContainerBlockHeaderRec_v2;ReadData:boolean=true):AnsiString;
    procedure ReadCatalog;
    procedure ReadCatalog_v2;
    procedure ReadDocumentInt(offset:UInt32;data:TStream;out LastBlock:UInt32;out LastBlockFill:integer;out LastBlockSize:integer);
    procedure ReadDocumentInt_v2(offset:int64;data:TStream;out LastBlock:int64;out LastBlockFill:int64;out LastBlockSize:int64);

    procedure InitDataV1(CreateContainter:boolean=false);
    procedure InitDataV2(CreateContainter:boolean=false);

    procedure FlushDataIntV1;
    procedure FlushDataIntV2;

    procedure AddFileIntV1(FileName:WideString;data:TStream;CreationTime:TDateTime=0;ModificationTime:TDateTime=0);
    procedure AddFileIntV2(FileName:WideString;data:TStream;CreationTime:TDateTime=0;ModificationTime:TDateTime=0);
  public
    Function GetDocumentInfo(n:integer):TContainerDocumentRecord;
    function DocumentsCount:integer;
    property Files[n:integer]:TContainerDocumentRecord read GetDocumentInfo;default;
    property FormatVersion:integer read FFormatVersion;
    constructor Create(FileName:WideString;UseVersion:integer=0);overload;
    constructor Create(stream:TStream;UseVersion:integer=0;CreateContainter:boolean=false;OwnStream:boolean=false);overload;

    procedure FlushData;
    procedure AddFile(FileName:WideString;data:TStream;CreationTime:TDateTime=0;ModificationTime:TDateTime=0);
    destructor Destroy;override;
    procedure ReadDocument(offset:int64;data:TStream);
    procedure FillFilesList(sl:TStrings);

    function GetContainerV1Size():int64;
    property Stub:TBytes read Fv1Stub;
    procedure SetStub(st:TStream);
  end;

var
  DefaultStub:RawByteString;

function UsersDecode(encdata:AnsiString):WideString;
function UsersEncode(data:WideString;key:AnsiString=''):AnsiString;

function ParseList(const data:AnsiString;var idx:integer):TpfAnyElement;

function DateTimeTo1CTime(dt:TDateTime):int64;
function DateTimeFrom1CTime(dt:int64):TDateTime;

function TestIsStream1CContainer(st:TStream):boolean;
function TestIsStream1CContainer_v2(st:TStream):boolean;
function TestIsStream1CContainerBuf(const buf;TotalSize:Int64):boolean;
function TestIsStream1CContainerBuf_v2(const buf;TotalSize:Int64):boolean;

implementation
uses StrUtils,math;

Const
  stub_z : Array[0..2908] of byte = (
     131,255,  3,127,  0,  2,130,  0,  1,  5,135,  0,  2, 13, 10,134, 48,
       3, 51, 99, 32,133, 48,  1, 50,130, 48,  2, 32, 55,135,102,  5, 32,
      13, 10, 47,  2,130,  0,  2,174,  2,130,  0,131,255,  3,127,147,  9,
     130,  0,  2, 18, 10,130,  0,131,255,  3,127, 49, 12,130,  0,  2,112,
      12,130,  0,131,255,  3,127,143, 14,130,  0,  2,212, 14,130,  0,131,
     255,  3,127,243, 16,130,  0,  2, 58, 17,130,  0,131,255,  1,127,255,
       0,255,  0,255,  0,199,  0,  2, 13, 10,134, 48,  3, 54, 48, 32,134,
      48,  4, 54, 48, 32, 55,135,102,  6, 32, 13, 10,240, 80,135,130, 93,
       6, 67,  2,  0,240, 80,135,130, 93,  2, 67,  2,133,  0, 71, 51,  0,
      48,  0,102,  0,102,  0,101,  0, 52,  0, 99,  0, 99,  0, 45,  0,101,
       0,101,  0,102,  0, 50,  0, 45,  0, 52,  0, 51,  0, 55,  0, 49,  0,
      45,  0, 56,  0, 98,  0, 50,  0, 54,  0, 45,  0, 48,  0, 52,  0, 54,
       0, 53,  0, 57,  0, 55,  0,101,  0, 51,  0, 55,  0,101,  0, 50,  0,
      50,133,  0,  2, 13, 10,133, 48,  4, 54, 99, 54, 32,133, 48,  5, 54,
      99, 54, 32, 55,135,102,126, 32, 13, 10,189, 88, 75,142, 36, 55, 14,
     221, 27,240, 29, 10, 53,219, 20, 32, 82,162, 72, 45,167,198, 51,247,
      16,245, 57,192,  0,179, 50,250,100, 94,248, 72,190,194,188,136,204,
     136,172,242,167, 93, 70, 52,156, 40,  4,148, 89, 20, 69,145,124,143,
     100,252,242,211,207, 63,242,237,251,239,126, 76,113,173,153,123, 15,
     115, 46, 14, 57, 41,  5,115, 46, 33,230, 34, 85,103,210,201,252,229,
      86, 54,209,218,135, 80,236, 35, 52, 95, 61, 16,141, 28,106, 78, 57,
     196,152, 99,149, 73,188,186,110,114,180, 61,164,110,207,126,184, 61,
     248,254, 99,188, 73,106, 85, 74, 93,193,138,198,144,179, 91,240,204,
      57,140, 57,121,244, 89,203, 20,253,114,123,125,123, 83,250,193,222,
     126, 16, 45, 37, 83, 36,179,250, 86,229, 95, 41,255,231,223,255,228,
      36,244,122,215,247,250,223,255,189, 66,248,197,149, 94,134,189,248,
     203,120,183,225,197,171,188,244,148, 95,142, 61,208,251, 10, 19,248,
     166,171,104, 73,148,131, 82,105, 33, 15,201,193, 82,146,208,148, 90,
      50, 81,103,234,183,116,171, 99,245,230,190, 66,105, 10, 49,107, 45,
     152, 50,133,177,100, 24,170,121, 42,218, 11,196,226,227, 19,126,231,
     113,124,190,124,255,221,126,250,238,151,248,229, 15,130,159,126,209,
     117,107, 51,245,145, 70, 11,141, 58,124,232, 54,131,205,177,112, 17,
     150,105,240,176,228,249, 57, 77,159, 19,218, 12,191,255,221,205,191,
     193,208,247,171,111,120,212, 55, 19,178,152,168,156, 54,110,151,248,
     155, 13, 56, 64,240,250, 15,184, 77,163,173,129,244,233,222,103,200,
     108, 53,120,210, 20,162, 54,105,154,125,206, 74, 55,218,115,228,219,
      25,192,159, 19, 75,167,147, 54,152,230,237,249,176, 26,148, 32,105,
     213, 28,166, 44, 13,185,  1,230,214, 41,  6, 38,243, 97, 68,189, 77,
     186,213,125,223,235, 27, 82,128,181,219,255, 23,183,211,197,237,241,
     218,126,190,182, 61, 93,219, 46,215,182,151,107,219,245,218,118,187,
      24,185,171,145,191, 24, 58,186,232, 61,186,232, 62,186,234,191,139,
     192,227,171,200,185, 24, 63,190, 24, 63,190,136, 61,206, 23,247, 95,
       4, 47, 95,204, 63,190,152,127,252,204,191,189,240,108, 42,120, 43,
     241,247,194, 73,130,127,126,193,252,100, 31,177,215,213,123,157,218,
     141,188,215,173,115,149,206,149,156,171,114,174,244, 92,217,185,170,
     231,138,226,115,249,212, 77, 79,229,244,212, 68, 79, 85,244,212, 69,
      79,101,252, 84,198,239, 12,125, 42,227,167,169,184,206,185,124,154,
     205,207,211,248,121, 26,219,230,169, 35,228,241,177,228,123, 25,175,
     154,138, 71, 14,181,183, 30,242, 76, 11,205, 53,114, 96,164, 89,209,
      24, 55,175,217, 30,106, 98,183,218,181,114,160,210,211,214,200, 75,
     240, 90, 28,190,150,232,109, 70,116,233,227, 16,197,112,108, 96,213,
     144, 64,194, 99, 19, 45,161,165,174, 79, 81,213,114,138,174,213, 99,
     237,193, 86,134,  1,138,153,194, 51,225,235,144, 46,141,153,134,214,
     211,195, 62,218, 50,  9, 67,218, 64,235, 90, 41,184, 99, 16,104, 45,
     206, 57, 41,213, 40,124,136,138,214, 44, 37,133,222, 39,180,210,130,
       1,150, 48,174,116, 36,184,215, 38,222,233,244,100,199,252,146, 45,
     244,154, 44,100, 25, 17,103,163,209,143,132, 33,163, 41, 59,209, 60,
      50, 37, 14,145,130, 60,126, 72, 38, 52,101,171,112,176,138,153,  4,
      77,117, 25,125, 77,103,239,135,168, 46, 94,173,182,224,172,229,156,
     122,228,227,212,243, 16,173, 62,198,194, 84, 17, 59, 44,204,194, 30,
      42,166,137, 48,106,237, 11,170,121,145, 31,162, 83,114,204, 13,227,
     197, 92,176,181,163, 33,108,131, 40, 84,120,134,199,106, 61,119, 59,
      69, 21,243, 22,154,253, 88,244, 79, 66,144,139,231, 62,170,134, 53,
      40, 33,  7,208,117, 54,111, 28, 18,236, 26, 90, 42,172, 57,180,230,
     105,108,163, 97,208, 91, 57, 99,142, 16, 15,190, 77, 20,126,141, 61,
     193,  1,234,163, 31, 30, 16,179,108, 24,173, 66, 42, 19,163, 80,132,
      27,204,  0, 77, 52,174,211,115,149, 26,199,225,  1, 29,125,228, 52,
     106,104,189, 73,200, 21,131,164, 75,174,129, 44,243, 44, 13,135,246,
     117,128, 80,180,231,134,200,131,169, 96,  0,174,140,177, 16, 33, 86,
      28,197,101, 17, 88,235,176,213,138,104, 76, 60,131,106,198,204, 51,
       9, 35,104,242, 22,100,140, 50,173, 45, 87, 59,180, 62,102,212,249,
     213, 25,149, 62, 53, 69,237,250,218,146,140,  4,140, 33,113, 65,156,
      82, 94, 56,122,106, 79,152, 89, 71, 25, 92,146,245,244, 56,186,199,
      44,177,214, 25, 40,121,197,133,188,132, 58, 36,  6,204,145, 49,114,
     228,170,103,250,245,142,241, 82,171,  5,237,160,234, 92,  8,162, 58,
      56, 40,  0,224,234, 93, 72, 14, 81,156, 17,107, 89,142,255,201,  6,
     149,  5,223, 46,192,  1,231,199,172, 74, 72, 77,191,243,192,131, 21,
     130,234,126,184, 68,195,173,140,249,240,192,134,130,104, 49, 35,226,
      68,171,222,137,241,152, 82, 30,108, 10,139, 88, 82, 78, 65, 99,116,
     196, 14,  4, 82,  9,247,237,213, 58, 40,133, 34,180,124,110, 70,193,
      92, 40, 59, 35, 16, 92,110, 17, 60,  0, 20,127, 29, 58,177,208,192,
     124,141,152, 34,254,240, 72,156,161, 10, 82, 98, 14, 69, 26, 39,248,
     220,242, 33,170, 19, 95,144, 89,166,139, 14,246,  2,237,252, 14,123,
      81,162,148, 57, 82, 88,  5, 87,218, 69,255,  8, 58,212, 69,103,115,
     228, 88, 66,190,230,236,  9, 86,143, 25, 15,166, 47,252, 92,212,225,
     240,131,103, 22, 53, 33,152,185, 28,130,102,126,143,130,107, 97,172,
      27,125, 75,200, 76,156, 78,166, 77,165,217, 76, 25,225,109,192, 34,
     240,142,225,111,248,  8,150, 28, 25, 72,170, 85,245,196, 46,177, 15,
     149,160,228, 91,229, 22,224,161,119,  9,236,209,139,172,186, 90, 60,
      12, 40,  9, 34, 91,136,185, 78,254, 58, 35, 24, 55,194,118, 28,203,
      28, 55,166,  5,201,130,165,  2,101, 28,  5,254,148,118,218,234,  5,
     255,110, 72,117, 42,249, 79,180, 34, 67,225,124, 40, 76,  2,172,127,
      93,116, 89, 22, 34,  3,128, 20, 89, 85,140,193,  8,189,  4, 54, 25,
      12,186,  8,119,174,135,104, 95, 25,  1,  0,130, 37, 11,245, 51,115,
     227,250,152,185,119, 81,144,172,130, 69, 42,160, 80, 63,224,172, 45,
      97, 77,168,134, 84,183, 32,172,197,146,249, 68,197,  3, 24, 51, 21,
      67,117,160, 16,219,158, 98,220,129,126,176, 90, 93, 41, 75,205,171,
     186,183,130, 19, 37,241,232, 49,  8,152, 24,169,128,237, 24,140,147,
      43, 34, 14,106,220,222,148, 13,238, 53,178, 84,116,147,247,  6,106,
     175,235, 54,117, 26,110,139,242,130,  4,126,226, 30,  6,170, 10,  6,
     166,244,217,157,227, 60,179,104,204, 57,170,219,230,180,  2,186, 88,
     224,172,140, 50,208, 57, 54,148,101,248,102, 47, 65,239,128, 61, 38,
     225,124,112, 79,103,224,191, 97,  5, 98, 64,141, 19, 65,145,241,226,
     146,252,215,152, 46,169,136, 12,109, 33,153, 35,252,  8,253, 78,240,
      80, 81, 71,130,134,130,194,242,180, 62, 69,167, 24, 17, 76,  4,  5,
     214, 43,240,215, 38,194,218,221,122, 51,112,162,150, 35, 91, 23,204,
      55,109, 22, 74,158, 32,122,153,155, 98,116,  8,158,218, 28, 13,144,
     136, 52, 83, 63, 88, 47,132, 45, 50, 44,204,150,193, 99,177,160, 49,
      53,180, 32,198, 85, 72, 37,162,243,156,191,245,126,198,  5,  1, 20,
      14, 17, 85,  6,168,236, 21,180,  0, 98,210,213, 39, 66,  1,166,107,
     239,237,159,130, 37, 67,  1,112, 40, 41,200, 26,146,193, 39,174, 12,
      28,187,128,143, 17,  1, 57,236,  7,253,163,  0,131,172,101,115,166,
     161, 98, 84, 71, 41,128, 74,  7,111, 22,203,141, 62,216, 63,139,145,
     241, 86,255, 56, 33,123,146, 37,120, 95, 65,145,177,211, 76, 73, 17,
      45,253,181,247,155,130,131, 20,181,192, 43,117,110, 13, 73,131,245,
      19,103,122, 55,244, 46, 19,217, 31,125,215,130,127, 36, 99,202, 10,
       0,162,106,213,158, 54,174,216,222,196, 46, 65, 86, 68,152,212,156,
     211,152,242,193,164,221, 81,251,187,185,199,143,255,  7, 13, 10,134,
      48,  3, 54, 48, 32,134, 48,  4, 54, 48, 32, 55,135,102,  6, 32, 13,
      10,240, 80,135,130, 93,  6, 67,  2,  0,240, 80,135,130, 93,  2, 67,
       2,133,  0, 71, 97,  0,101,  0, 51,  0, 99,  0,100,  0, 51,  0,100,
       0, 97,  0, 45,  0, 97,  0, 49,  0, 99,  0, 48,  0, 45,  0, 52,  0,
      98,  0, 56,  0,101,  0, 45,  0, 56,  0,101,  0,100,  0,102,  0, 45,
       0, 52,  0,100,  0, 50,  0, 53,  0,101,  0, 56,  0, 53,  0, 51,  0,
      97,  0, 53,  0, 52,  0,101,133,  0,  2, 13, 10,134, 48,  3, 54, 55,
      32,133, 48,  1, 50,130, 48,  2, 32, 55,135,102, 80, 32, 13, 10,123,
     191,123,127,181,161, 14, 47, 87,181,  1,136, 48,  2, 17,134, 58,  6,
      58,137,169,198,201, 41,198, 41,137,186,137,134,201,  6,186, 38, 73,
      22,169,186, 22,169, 41,105,186, 38, 41, 70,166,169, 22,166,198,137,
     166, 38,169,181, 58, 74, 23, 22, 92,108,190,216,120,177,241,194,174,
      11, 59, 46,236, 84,130,232, 86,130, 42, 23, 85,194,144,  2, 42, 86,
       2,154, 11,132, 80,160,139,133,128,129, 90,176, 25,181, 58,  6,181,
     255,  0,255,  0,255,  0,157,  0,  2, 13, 10,134, 48,  3, 50, 48, 32,
     134, 48,  4, 50, 48, 32, 55,135,102,  6, 32, 13, 10,240, 80,135,130,
      93,  6, 67,  2,  0,240, 80,135,130, 93,  2, 67,  2,133,  0,  7,114,
       0,111,  0,111,  0,116,133,  0,  2, 13, 10,134, 48,  3, 56, 57, 32,
     133, 48,  1, 50,130, 48,  2, 32, 55,135,102, 12, 32, 13, 10,123,191,
     123,127,181,145,142,177, 65,130, 90,  5,170, 73,114,178,110,130,106,
      23,154,145,174,137,177,185,161,174, 69,146,145,153,174,129,137,153,
     169,165,121,170,177,121,170,130,145,  2, 78,134,130,169, 19,190,111,
     122,170, 81,154,175, 91, 85, 73, 96,177, 91,102,113, 88,142,135,113,
     130, 68,  9,164, 83,190,126, 98, 90, 70, 89, 68,130, 97, 29,113,106,
     170,169,137,119,166,177,183,185,123, 97, 86,106, 90,112,105, 73,168,
     105,166,155,139,169,187, 91, 68,178, 17,130, 47, 26,151,163, 95,149,
     185,187, 79,106,166,101, 74,169,161,135, 81,106,105,164,167, 95,120,
      96,186,173,109, 45,255,  0,255,  0,250,  0,  2, 13, 10,134, 48,  3,
      50, 54, 32,134, 48,  4, 50, 54, 32, 55,135,102,  6, 32, 13, 10,240,
      80,135,130, 93,  6, 67,  2,  0,240, 80,135,130, 93,  2, 67,  2,133,
       0, 13,118,  0,101,  0,114,  0,115,  0,105,  0,111,  0,110,133,  0,
       2, 13, 10,134, 48,  3, 49, 97, 32,133, 48,  1, 50,130, 48,  2, 32,
      55,135,102, 18, 32, 13, 10,123,191,123,127, 53, 47, 87,181,145,161,
     153,142,129, 14,144,130, 97,  8, 96, 12, 98,214,242,114,129, 16,255,
       0,255,  0,255,  0,234,  0,  2, 13, 10,134, 48,  3, 50, 56, 32,134,
      48,  4, 50, 56, 32, 55,135,102,  6, 32, 13, 10,240, 80,135,130, 93,
       6, 67,  2,  0,240, 80,135,130, 93,  2, 67,  2,133,  0, 15,118,  0,
     101,  0,114,  0,115,  0,105,  0,111,  0,110,  0,115,133,  0,  2, 13,
      10,134, 48,  3,101, 50, 32,133, 48,  1, 50,130, 48,  2, 32, 55,135,
     102, 40, 32, 13, 10, 61,207, 63, 78,  6, 48,  8,135,225,187,116, 46,
      73,129,210, 63,199,  1, 10,137,139, 95,242,105, 92,140, 39,115,240,
      72, 94,193, 78,110, 12, 79,194,130,251, 23,253,254,249,196, 58,106,
      41,213,218, 70,117, 78,104,232, 12, 61,140,193, 84, 21,140,101, 19,
     130,169,126,251,169,133, 91,102,116,119,136, 72,130,206, 19, 97, 25,
      13,104,125,200,158,193, 51,136, 74,157,227,184,236, 70,192,212, 22,
     244, 61,245, 42, 51, 48,153,182,208,251,118,146, 90, 52,216, 15, 31,
       5, 69,111,208,109,  5,172, 56,  9,253,144,196, 18, 86,233, 81, 42,
      46, 12,196, 52,104, 62,  6,244, 46,116, 61,251,189,  8,207,110, 44,
      99,104, 45,207,199,227,189, 84, 14,242,169, 27, 97,156,188,150, 44,
      64,183,108,104, 49, 69,250, 84, 36,143, 90, 62,226,249,246,242,120,
      45,149, 38,222, 92, 71,144,153,120,223, 36,238,155,178, 81, 32,227,
     104,230,  8, 78,242,127,254,118,125, 28, 15,211, 14,123,196, 13, 78,
     158,176,239,104, 48,242, 33,166,147, 41,243,235, 15,255,  0,255,  0,
     160,  0);

function DateTimeTo1CTime(dt:TDateTime):int64;
var
  ts:TTimeStamp;
begin
  ts:=DateTimeToTimeStamp(dt);
  result:=(int64(ts.Date-1)*MSecsPerDay+ts.Time)*10;
end;

function DateTimeFrom1CTime(dt:int64):TDateTime;
var
  ts:TTimeStamp;
begin
  dt:=dt div 10;
  ts.Time:=dt mod (24*60*60*1000);
  ts.Date:=dt div (24*60*60*1000)+1;
  result:=TimeStampToDateTime(ts);
end;

function UsersDecode(encdata:AnsiString):WideString;
var
  i:integer;
  ds:integer;
  es:integer;
begin
  es:=byte(encdata[1]);
  ds:=es+2;
  for i:=ds to length(encdata) do begin
    encdata[i]:=AnsiChar(byte(encdata[i]) xor byte(encdata[((i-ds)mod es)+2]));
  end;
//  SetLength(result,(length(encdata)-es-1)div 2);
//  move(encdata[ds],result[1],(length(encdata)-es-1)div 2);
  encdata:=copy(encdata,ds,length(encdata));
  if copy(encdata,1,3)=#$EF#$BB#$BF then encdata:=copy(encdata,4,length(encdata));

  result:=UTF8Decode(encdata);
end;

function UsersEncode(data:WideString;key:AnsiString=''):AnsiString;
var
  i:integer;
  es,ds:integer;
begin
  if key='' then begin
    es:=random(10)+2;
    SetLength(key,es);
    for i := 2 to es do
      key[i]:=AnsiChar(random(256));
  end else begin
    es:=length(key);
  end;
  ds:=es+2;
  result:=AnsiChar(byte(length(key)))+key+#$EF#$BB#$BF+UTF8Encode(data);
//  SetLength(result,length(result)+length(data)*2);
//  move(data[1],result[ds],length(data)*2);
  for i:=ds to length(result) do begin
    result[i]:=AnsiChar(byte(result[i]) xor byte(result[((i-ds)mod es)+2]));
  end;
end;

function ParseString(const data:AnsiString;var idx:integer):AnsiString;
var
  i:integer;
begin
  i:=idx+1;
  while i<=length(data) do begin
    if (data[i]='"') then begin
      if (i<length(data))and(data[i+1]<>'"') then begin
        result:=AnsiReplaceStr(copy(data,idx+1,i-idx-1),'""','"');
        idx:=i;
        exit;
      end else inc(i);
    end;
    inc(i);
  end;
  result:=AnsiReplaceStr(copy(data,idx,length(data)),'""','"');
  idx:=i;
end;

function s2s(s:AnsiString):AnsiString;
var
  i:integer;
begin
  result:='';
  for i:=1 to length(s) do
    if s[i]='"' then
      result:=result+'\"'
    else if s[i]='\' then
      result:=result+'\\'
    else result:=result+s[i];
end;

procedure SkipSpaces(const data:AnsiString;var idx:integer);
begin
  while idx<length(data) do begin
    if data[idx] in [#13,#10,' '] then inc(idx) else break;
  end;
end;

function FindComma(const data:AnsiString;idx:integer):integer;
begin
  result:=idx;
  while (result<=length(data)) do begin
    if data[result] in [',','}'] then exit;
    inc(result);
  end;
end;

function ParseList(const data:AnsiString;var idx:integer):TpfAnyElement;
var
//  ListDepth:integer;
  i,i1:integer;
  s:AnsiString;
//  t:TpfAnyElement;
  tp:TpfElementType;
begin
//  ListDepth:=0;
  if (idx=1)and(copy(data,1,3)=#$EF#$BB#$BF) then idx:=4;
  
  result:=TpfAnyElement.Create(etList);
//  result._type:=;
  SkipSpaces(data,idx);
  i:=idx;
//  result:=Unassigned;
  while i<=length(data) do begin
//writeln(i,'-',result);
    if data[i]='{' then begin
//      inc(ListDepth);
      inc(i);
      Result.ValueAdd(ParseList(data,i));
    end else if data[i]='"' then begin
//      t._type:=etString;
//      t.valueStr:=ParseString(data,i);
      Result.valueAdd(etString,ParseString(data,i));
    end else if data[i]='}' then begin
//      dec(ListDepth);
//      if ListDepth<0 then begin
        idx:=i+1;
        exit;
//      end;
    end else if data[i]=',' then begin
      Result.ValueAdd(etNull,'');
    end else begin
      i1:=FindComma(data,i);
      s:=copy(data,i,i1-i);
      i:=i1-1;
//      t.valueStr:=s;
      if (length(s)=36)and(s[9]='-')and(s[14]='-')and(s[19]='-')and(s[24]='-') then
//        t._type:=etGuid
        tp:=etGuid
      else
//        t._type:=etNumeric;
        tp:=etNumeric;
      Result.valueAdd(tp,s);
    end;

    inc(i);
    SkipSpaces(data,i);
    if data[i]=',' then begin
      inc(i);
      SkipSpaces(data,i);
    end;

    idx:=i;
  end;
end;

{ TBigSet }

constructor TBigSet.Create(maxval: integer);
begin
  SetLength(FData,(maxval+1+31)div 32);
  FillChar(FData[0],Length(FData)*SizeOf(FData[0]),0);
  FMaxVal:=maxval;
end;

function TBigSet.GetBit(idx: integer): boolean;
var
  w:Cardinal;
begin
  w:=FData[idx div 32];
  result:=((w shr (idx mod 32))and 1)=1;
end;

procedure TBigSet.SetBit(idx: integer; value: boolean);
var
  w:Cardinal;
  i:integer;
begin
  i:=idx div 32;
  w:=FData[i];
  if value then
    FData[i]:=w or (1 shl (idx mod 32))
  else
    FData[i]:=w and not(1 shl (idx mod 32));
end;

function TBigSet.TestAndSetBit(idx: integer; value: boolean): boolean;
var
  w,t:Cardinal;
  i:integer;
begin
  i:=idx div 32;
  w:=FData[i];
  t:=1 shl (idx mod 32);
  result:=(w and t)<>0;
  if value then
    FData[i]:=w or t
  else
    FData[i]:=w and not t;
end;

{ TpfAnyElement }

constructor TpfAnyElement.Create(tp: TpfElementType; _value: string);
begin
  ValuesList:=TObjectList.Create;
  ValuesList.OwnsObjects:=true;
  _type:=tp;
  Value:=_value;
end;

destructor TpfAnyElement.Destroy;
begin
  FreeAndNil(ValuesList);
  inherited;
end;

function TpfAnyElement.GetElement(index: integer): TpfAnyElement;
begin
  result:=TpfAnyElement(ValuesList[index]);
end;

function TpfAnyElement.ToString: string;
var
  i:integer;
begin
  case _type of
    etList:
      begin
        result:='{';
        for i := 0 to ValuesList.Count - 1 do
          result:=result+IfThen(i=0,'',',')+IfThen(TpfAnyElement(ValuesList[i])._type=etList,#13#10,'')+TpfAnyElement(ValuesList[i]).ToString;
//          result:=result+IfThen(i=0,'',',')+TpfAnyElement(ValuesList[i]).ToString;
        result:=result+'}';
      end;
    etString:
      result:='"'+ReplaceStr(Value,'"','""')+'"';
    etNumeric:
      result:=Value;
    etGuid:
      result:=Value;
    etNull:
      result:='';
  else
    Raise Exception.Create('Unknown element type in AnyAlement.ToString()');
  end;
end;

procedure TpfAnyElement.ValueAdd(element: TpfAnyElement);
begin
  ValuesList.Add(element);
end;

procedure TpfAnyElement.ValueAdd(tp: TpfElementType; _value: string);
begin
  ValuesList.Add(TpfAnyElement.Create(tp,_value));
end;

{ T1CContainer }

procedure T1CContainer.AddFile(FileName: WideString; data: TStream;
  CreationTime: TDateTime; ModificationTime: TDateTime);
begin
  if FormatVersion=cfClassic then
    AddFileIntV1(FileName,data,CreationTime,ModificationTime)
  else
    AddFileIntV2(FileName,data,CreationTime,ModificationTime);
end;

constructor T1CContainer.Create(FileName:WideString;UseVersion:integer=0);
begin
  FOwnStream:=true;
  FModified:=false;
  if FileExists(FileName) then begin
    FStream:=TFileStream.Create(FileName,fmOpenReadWrite or fmShareDenyWrite);
    Create(FStream,UseVersion,false,true);
  end else begin
    FStream:=TFileStream.Create(FileName,fmCreate or fmShareDenyWrite);
    Create(FStream,UseVersion,True,True);
  end;
end;

constructor T1CContainer.Create(stream: TStream; UseVersion:integer;
    CreateContainter: boolean; OwnStream: boolean);
var
  i:Integer;
begin
  FStream:=stream;
  FOwnStream:=OwnStream;
  FModified:=false;
  Fv1StubSize:=0;
  SetLength(Fv1Stub,0);

  FLastBlockOffset:=0;
  FLastBlockSize:=SizeOf(T1CContainerHeader);

  case UseVersion of
    cfAuto:
      begin
        if CreateContainter then
          InitDataV1(CreateContainter)
        else begin
          FStream.Position:=0;
          if TestIsStream1CContainer_v2(FStream) then begin
            InitDataV2(CreateContainter);
          end else begin;
            InitDataV1(CreateContainter);
            i:=GetContainerV1Size();
            if (DocumentsCount<15)and(i<FStream.Size) then begin
              FStream.Seek(i,soBeginning);
              if TestIsStream1CContainer_v2(FStream) then begin
                InitDataV2(CreateContainter);
              end;
            end;
          end;
        end;
      end;
    cfClassic:
      InitDataV1(CreateContainter);
    cfNew:
      InitDataV2(CreateContainter);
  end;
end;

procedure T1CContainer.InitDataV1(CreateContainter:boolean);
var
  bh:T1CContainerBlockHeaderRec;
  buf:AnsiString;
begin
  FFormatVersion:=cfClassic;

  if CreateContainter then begin
    FModified:=true;
    Header.FreeBlockOffset:=MaxInt;
    Header.DefaultBlockSize:=$200;
    Header.ContainerVersion:=0;
    Header.reserved:=0;
    FStream.Seek(0,soBeginning);
    FStream.Write(Header,SizeOf(Header));
    FLastCatalogBlock:=FStream.Position;
    FLastCatalogBlockFill:=0;
    FLastCatalogBlockSize:=Header.DefaultBlockSize;
    bh.Init(0,Header.DefaultBlockSize,MaxInt);
//    bh.DocumentSize:='00000000';
//    buf:=LowerCase(IntToHex(Header.DefaultBlockSize,8));
//    bh.BlockSize:='00000200';
//    move(buf[1],bh.BlockSize[0],8);
//    bh.NextBlockOffset:='7fffffff';
    SetLength(buf,Header.DefaultBlockSize);
    FillChar(buf[1],Length(buf),0);
    FStream.Write(bh,SizeOf(bh));
    FStream.Write(buf[1],Length(buf));
  end else begin
    FStream.Seek(0,soBeginning);
    FStream.Read(Header,SizeOf(Header));
    FLastCatalogBlock:=FStream.Position;
    FLastCatalogBlockFill:=0;
    ReadCatalog;
  end;
  FDefaultBlockSize:=Header.DefaultBlockSize;
end;

procedure T1CContainer.InitDataV2(CreateContainter: boolean);
var
  bh:T1CContainerBlockHeaderRec_v2;
  buf:AnsiString;
  cf:T1CContainer;
  st:TStream;
begin
  FFormatVersion:=cfNew;

  if CreateContainter then begin
    st:=TMemoryStream.Create;
    if DefaultStub<>'' then
      st.Write(DefaultStub[1],Length(DefaultStub));
    st.Position:=0;
    Fv1StubSize:=st.Size;
    SetLength(Fv1Stub,Fv1StubSize);
    st.Read(Fv1Stub[0],Fv1StubSize);
    st.Free;

    FModified:=true;
    Header_v2.FreeBlockOffset:=Int64(-1);
    Header_v2.DefaultBlockSize:=$200;
    Header_v2.ContainerVersion:=0;
    Header_v2.reserved:=0;
    FStream.Seek(0,soBeginning);
    FStream.Write(Fv1Stub[0],Fv1StubSize);
    FStream.Write(Header_v2,SizeOf(Header_v2));
    FLastCatalogBlock_v2:=FStream.Position-Fv1StubSize;
    FLastCatalogBlockFill_v2:=0;
    FLastCatalogBlockSize_v2:=DefaultCatalogBlockSizeV2;
    bh.Init(0,FLastCatalogBlockSize_v2,Int64(-1));
    SetLength(buf,FLastCatalogBlockSize_v2);
    FillChar(buf[1],Length(buf),0);
    FStream.Write(bh,SizeOf(bh));
    FStream.Write(buf[1],Length(buf));
  end else begin
    FStream.Position:=0;
    if not TestIsStream1CContainer_v2(FStream) then begin
      InitDataV1(false);
      FFormatVersion:=cfNew;
      Fv1StubSize:=GetContainerV1Size();
      SetLength(Fv1Stub,Fv1StubSize);
      FStream.Seek(0,soBeginning);
      FStream.Read(Fv1Stub[0],Fv1StubSize);
    end;
    FStream.Position:=Fv1StubSize;

    FStream.Read(Header_v2,SizeOf(Header_v2));
    FLastCatalogBlock_v2:=FStream.Position-Fv1StubSize;
    FLastCatalogBlockFill_v2:=0;
    ReadCatalog_v2;
  end;
  FDefaultBlockSize:=Header_v2.DefaultBlockSize;
end;

procedure T1CContainer.FlushDataIntV1;
var
  bh:T1CContainerBlockHeaderRec;
begin
    FStream.Seek(0,soBeginning);
    FStream.Write(Header,SizeOf(Header));
    ReadBlock(SizeOf(Header),bh,false);
    FStream.Seek(SizeOf(Header),soBeginning);
    bh.SetDocSize(SizeOf(T1CContainerEntryRec)*Length(FFilesList));
    FStream.Write(bh,SizeOf(bh));
end;

procedure T1CContainer.FlushDataIntV2;
var
  bh2:T1CContainerBlockHeaderRec_v2;
begin
  FStream.Seek(Fv1StubSize,soBeginning);
  FStream.Write(Header_v2,SizeOf(Header_v2));
  ReadBlock_v2(SizeOf(Header_v2),bh2,false);
  FStream.Seek(SizeOf(Header_v2)+Fv1StubSize,soBeginning);
  bh2.SetDocSize(SizeOf(T1CContainerEntryRec_v2)*Length(FFilesList));
  FStream.Write(bh2,SizeOf(bh2));
end;

procedure T1CContainer.AddFileIntV1(FileName: WideString; data: TStream;
  CreationTime: TDateTime; ModificationTime: TDateTime);
var
  fr:TContainerDocumentRecord;
  ce:T1CContainerEntryRec;
  bh:T1CContainerBlockHeaderRec;
  par:P1CContainerDocAttributesRec;
  buf:AnsiString;
  i:integer;
  parsize:integer;
  ChunkSize:integer;
  CurPos:integer;
  DataSize:integer;
begin
  FModified:=true;
  fr.Name:=FileName;
  fr.CreationTime:=CreationTime;
  if fr.CreationTime<=0 then fr.CreationTime:=now;
  fr.ModificationTime:=ModificationTime;
  if fr.ModificationTime<=0 then fr.ModificationTime:=now;

  inc(Header.ContainerVersion);

  data.Position:=0;

  ce.reserved:=MaxInt;
  ce.OffsetAttrs:=FStream.Size;
  parsize:=SizeOf(T1CContainerDocAttributesRecAttrsOnly)+Length(FileName)*2+4;
//  SetLength(buf,((parsize+$f)div $10)*$10);
  SetLength(buf,parsize);
  FillChar(buf[1],Length(buf),0);

  par:=Pointer(PAnsiChar(buf));
  par.DocCreationTime:=DateTimeTo1CTime(fr.CreationTime);
  par.DocModificationTime:=DateTimeTo1CTime(fr.ModificationTime);
  par.reserved:=0;
  move(PWideChar(FileName)^,par.FileName,length(FileName)*2);
  bh.Init(parsize,length(buf),MaxInt);
  FStream.Seek(0,soEnd);
  FStream.Write(bh,SizeOf(bh));
  FStream.Write(buf[1],Length(buf));

  ce.OffsetData:=FStream.Size;
  fr.BlockOffset:=ce.OffsetData;
  DataSize:=data.Size;
  fr.Size:=DataSize;
//  bh.Init(DataSize,Header.DefaultBlockSize,MaxInt);
//  SetLength(buf,Header.DefaultBlockSize);
  if DataSize<=MaxChunkSizeV1 then begin;
    bh.Init(DataSize,DataSize,MaxInt);
    SetLength(buf,DataSize);
  end else begin
    bh.Init(DataSize,MaxChunkSizeV1,MaxInt);
    SetLength(buf,MaxChunkSizeV1);
  end;
  CurPos:=0;
  repeat
    FillChar(buf[1],Length(buf),0);
    ChunkSize:=DataSize-CurPos;
    if Length(buf)<ChunkSize then begin
      ChunkSize:=Length(Buf);
      bh.SetNextBlock(FStream.Size+SizeOf(bh)+Length(buf));
    end else begin
      bh.NextBlockOffset:='7fffffff';
      bh.BlockSize:=LowerCase(IntToHex(ChunkSize,8));
      SetLength(buf,ChunkSize);
    end;
    data.Read(buf[1],ChunkSize);
    FStream.Write(bh,SizeOf(bh));
    FStream.Write(buf[1],Length(buf));
    inc(CurPos,ChunkSize);

    bh.DocumentSize:='00000000';
  until CurPos>=DataSize;

  if (FLastCatalogBlockSize-FLastCatalogBlockFill)<SizeOf(ce) then begin
    ReadBlock(FLastCatalogBlock,bh,false);
    bh.SetNextBlock(FStream.Size);
    FStream.Seek(FLastCatalogBlock,soBeginning);
    FStream.Write(bh,SizeOf(bh));
    SetLength(buf,SizeOf(ce));
    move(ce,buf[1],SizeOf(ce));
    CurPos:=0;
    if (FLastCatalogBlockFill<FLastCatalogBlockSize) then begin
      FStream.Seek(FLastCatalogBlockFill,soCurrent);
      CurPos:=FStream.Write(buf[1],FLastCatalogBlockSize-FLastCatalogBlockFill);
    end;
    bh.DocumentSize:='00000000';
    bh.NextBlockOffset:='7fffffff';
    FStream.Seek(0,soEnd);
    FLastCatalogBlock:=FStream.Size;
    FStream.Write(bh,SizeOf(bh));
    FLastCatalogBlockFill:=SizeOf(ce)-CurPos;
    buf:=copy(buf,CurPos+1,FLastCatalogBlockFill);
    SetLength(buf,FLastCatalogBlockSize);
    FillChar(buf[FLastCatalogBlockFill+1],FLastCatalogBlockSize-FLastCatalogBlockFill,0);
    FStream.Write(buf[1],Length(buf));
  end else begin
    FStream.Seek(FLastCatalogBlock+SizeOf(bh)+FLastCatalogBlockFill,soBeginning);
    FStream.Write(ce,SizeOf(ce));
    inc(FLastCatalogBlockFill,SizeOf(ce));
  end;

  i:=Length(FFilesList);
  SetLength(FFilesList,i+1);
  FFilesList[i]:=fr;
end;

procedure T1CContainer.AddFileIntV2(FileName: WideString; data: TStream;
  CreationTime: TDateTime; ModificationTime: TDateTime);
var
  fr:TContainerDocumentRecord;
  ce2:T1CContainerEntryRec_v2;
  bh2:T1CContainerBlockHeaderRec_v2;
  par:P1CContainerDocAttributesRec;
  buf:AnsiString;
  i:integer;
  parsize:integer;
  ChunkSize:int64;
  CurPos:integer;
  DataSize:int64;
begin
  FModified:=true;
  fr.Name:=FileName;
  fr.CreationTime:=CreationTime;
  if fr.CreationTime<=0 then fr.CreationTime:=now;
  fr.ModificationTime:=ModificationTime;
  if fr.ModificationTime<=0 then fr.ModificationTime:=now;

  inc(Header_v2.ContainerVersion);

  data.Position:=0;

  ce2.reserved:=int64(-1);
  ce2.OffsetAttrs:=FStream.Size-Fv1StubSize;
  parsize:=SizeOf(T1CContainerDocAttributesRecAttrsOnly)+Length(FileName)*2+4;
//  SetLength(buf,((parsize+$f)div $10)*$10);
  SetLength(buf,parsize);
  FillChar(buf[1],Length(buf),0);

  par:=Pointer(PAnsiChar(buf));
  par.DocCreationTime:=DateTimeTo1CTime(fr.CreationTime);
  par.DocModificationTime:=DateTimeTo1CTime(fr.ModificationTime);
  par.reserved:=0;
  move(PWideChar(FileName)^,par.FileName,length(FileName)*2);
  bh2.Init(parsize,length(buf),int64(-1));
  FStream.Seek(0,soEnd);
  FStream.Write(bh2,SizeOf(bh2));
  FStream.Write(buf[1],Length(buf));

  ce2.OffsetData:=FStream.Size-Fv1StubSize;
  fr.BlockOffset:=ce2.OffsetData;
  DataSize:=data.Size;
  fr.Size:=DataSize;
  if DataSize<=MaxChunkSizeV2 then begin;
    bh2.Init(DataSize,DataSize,int64(-1));
    SetLength(buf,DataSize);
  end else begin
    bh2.Init(DataSize,MaxChunkSizeV2,int64(-1));
    SetLength(buf,MaxChunkSizeV2);
  end;
  CurPos:=0;
  repeat
    FillChar(buf[1],Length(buf),0);
    ChunkSize:=DataSize-CurPos;
    if Length(buf)<ChunkSize then begin
      ChunkSize:=Length(Buf);
      bh2.SetNextBlock(FStream.Size+SizeOf(bh2)+Length(buf)-Fv1StubSize);
    end else begin
      bh2.NextBlockOffset:='FFFFFFFFFFFFFFFF';
      bh2.BlockSize:=UpperCase(IntToHex(ChunkSize,16));
      SetLength(buf,ChunkSize);
    end;
    data.Read(buf[1],ChunkSize);
    FStream.Write(bh2,SizeOf(bh2));
    FStream.Write(buf[1],Length(buf));
    inc(CurPos,ChunkSize);

    bh2.DocumentSize:='0000000000000000';
  until CurPos>=DataSize;

  if (FLastCatalogBlockSize_v2-FLastCatalogBlockFill_v2)<SizeOf(ce2) then begin
    ReadBlock_v2(FLastCatalogBlock_v2,bh2,false);
    bh2.SetNextBlock(FStream.Size-Fv1StubSize);
    FStream.Seek(FLastCatalogBlock_v2+Fv1StubSize,soBeginning);
    FStream.Write(bh2,SizeOf(bh2));
    SetLength(buf,SizeOf(ce2));
    move(ce2,buf[1],SizeOf(ce2));
    CurPos:=0;
    if (FLastCatalogBlockFill_v2<FLastCatalogBlockSize_v2) then begin
      FStream.Seek(FLastCatalogBlockFill_v2,soCurrent);
      CurPos:=FStream.Write(buf[1],FLastCatalogBlockSize_v2-FLastCatalogBlockFill_v2);
    end;
    bh2.DocumentSize:='0000000000000000';
    bh2.NextBlockOffset:='FFFFFFFFFFFFFFFF';
    FStream.Seek(0,soEnd);
    FLastCatalogBlock_v2:=FStream.Size-Fv1StubSize;
    FStream.Write(bh2,SizeOf(bh2));
    FLastCatalogBlockFill_v2:=SizeOf(ce2)-CurPos;
    buf:=copy(buf,CurPos+1,FLastCatalogBlockFill_v2);
    SetLength(buf,FLastCatalogBlockSize_v2);
    FillChar(buf[FLastCatalogBlockFill_v2+1],FLastCatalogBlockSize_v2-FLastCatalogBlockFill_v2,0);
    FStream.Write(buf[1],Length(buf));
  end else begin
    FStream.Seek(FLastCatalogBlock_v2+SizeOf(bh2)+FLastCatalogBlockFill_v2+Fv1StubSize,soBeginning);
    FStream.Write(ce2,SizeOf(ce2));
    inc(FLastCatalogBlockFill_v2,SizeOf(ce2));
  end;

  i:=Length(FFilesList);
  SetLength(FFilesList,i+1);
  FFilesList[i]:=fr;
end;

destructor T1CContainer.Destroy;
begin
  FlushData;
  if FOwnStream then FStream.Free;
  inherited;
end;

function T1CContainer.DocumentsCount: integer;
begin
  result:=length(FFilesList);
end;

procedure T1CContainer.FlushData;
begin
  if FModified then begin
    if FormatVersion=cfClassic then
      FlushDataIntV1
    else
      FlushDataIntV2;
    FModified:=false;
  end;
end;

function T1CContainer.GetDocumentInfo(n: integer): TContainerDocumentRecord;
begin
  result:=FFilesList[n];
end;

function T1CContainer.ReadBlock(offset:UInt32;out BlockHeader:T1CContainerBlockHeaderRec;ReadData:boolean=true): AnsiString;
var
  r:integer;
begin
  Result:='';
  FStream.Seek(offset,soBeginning);
  r:=FStream.Read(BlockHeader,SizeOf(BlockHeader));
//writeln('ReadBlock @',IntToHex(offset,8),' -> ',BlockHeader.NextBlockOffset);
  if r=SizeOf(BlockHeader) then begin
    if offset>FLastBlockOffset then begin
      FLastBlockOffset:=offset;
      FLastBlockSize:=StrToInt('$'+BlockHeader.BlockSize)+SizeOf(BlockHeader);
    end;
  end else
    exit;
  if ReadData then begin
    SetLength(Result,StrToInt('$'+BlockHeader.BlockSize));
    FStream.Read(Result[1],Length(Result));
  end;
end;

function T1CContainer.ReadBlock_v2(offset: int64; out
  BlockHeader: T1CContainerBlockHeaderRec_v2; ReadData: boolean): AnsiString;
var
  r:integer;
begin
  Result:='';
  FStream.Seek(offset+Fv1StubSize,soBeginning);
  r:=FStream.Read(BlockHeader,SizeOf(BlockHeader));
//writeln('ReadBlock @',IntToHex(offset,8),' -> ',BlockHeader.NextBlockOffset);
  if r=SizeOf(BlockHeader) then begin
//    if offset>FLastBlockOffset then begin
//      FLastBlockOffset:=offset;
//      FLastBlockSize:=StrToInt('$'+BlockHeader.BlockSize)+SizeOf(BlockHeader);
//    end;
  end else
    exit;
  if ReadData then begin
    SetLength(Result,StrToInt64('$'+BlockHeader.BlockSize));
    FStream.Read(Result[1],Length(Result));
  end;
end;

procedure T1CContainer.ReadCatalog;
var
  stc:TStream;
  rh:T1CContainerEntryRec;
  de:TContainerDocumentRecord;
  par:P1CContainerDocAttributesRec;
  bh:T1CContainerBlockHeaderRec;
  sta:TMemoryStream;
  i:integer;
begin
  SetLength(FFilesList,0);
  stc:=TMemoryStream.Create;
  try
    ReadDocumentInt(SizeOf(Header),stc,FLastCatalogBlock,FLastCatalogBlockFill,FLastCatalogBlockSize);
    stc.Seek(0,soBeginning);
    while stc.Position<stc.Size do begin
      stc.Read(rh,SizeOf(rh));
      i:=Length(FFilesList);
      de.BlockOffset:=rh.OffsetData;
      sta:=TMemoryStream.Create;
      try
        ReadDocument(rh.OffsetAttrs,sta);
        par:=sta.Memory;
        de.CreationTime:=DateTimeFrom1CTime(par.DocCreationTime);
        de.ModificationTime:=DateTimeFrom1CTime(par.DocModificationTime);
        de.Name:=copy(par.FileName,0,(sta.Size-20-4)div 2);
        de.Size:=0;
        if rh.OffsetData>0 then begin
          ReadBlock(rh.OffsetData,bh,false);
          de.Size:=StrToInt('$'+bh.DocumentSize);
        end;
      finally
        sta.Free;
      end;
      SetLength(FFilesList,i+1);
      FFilesList[i]:=de;
    end;
  finally
    stc.Free;
  end;
end;

procedure T1CContainer.ReadCatalog_v2;
var
  stc:TStream;
  rh:T1CContainerEntryRec_v2;
  de:TContainerDocumentRecord;
  par:P1CContainerDocAttributesRec;
  bh:T1CContainerBlockHeaderRec_v2;
  sta:TMemoryStream;
  i:integer;
begin
  SetLength(FFilesList,0);
  stc:=TMemoryStream.Create;
  try
    ReadDocumentInt_v2(SizeOf(Header_v2),stc,FLastCatalogBlock_v2,FLastCatalogBlockFill_v2,FLastCatalogBlockSize_v2);
    stc.Seek(0,soBeginning);
    while stc.Position<stc.Size do begin
      stc.Read(rh,SizeOf(rh));
//writeln('RH: A ',IntToHex(rh.OffsetAttrs,16),' D ',IntToHex(rh.OffsetData,16));
      i:=Length(FFilesList);
      de.BlockOffset:=rh.OffsetData;
      sta:=TMemoryStream.Create;
      try
        ReadDocument(rh.OffsetAttrs,sta);
        par:=sta.Memory;
        de.CreationTime:=DateTimeFrom1CTime(par.DocCreationTime);
        de.ModificationTime:=DateTimeFrom1CTime(par.DocModificationTime);
        de.Name:=copy(par.FileName,0,(sta.Size-20-4)div 2);
        de.Size:=0;
//writeln('DE: ',de.Name,' S ',de.Size);
        if rh.OffsetData>0 then begin
          ReadBlock_v2(rh.OffsetData,bh,false);
          de.Size:=StrToInt64('$'+bh.DocumentSize);
        end else begin
//writeln('DE: ',de.Name,' S ',de.Size);
        end;
      finally
        sta.Free;
      end;
      SetLength(FFilesList,i+1);
      FFilesList[i]:=de;
    end;
  finally
    stc.Free;
  end;
end;

procedure T1CContainer.ReadDocument(offset: int64; data: TStream);
var
  lb:UInt32;
  lbf:integer;
  lbs:integer;
  lb2:int64;
  lbf2:int64;
  lbs2:int64;
begin
  if offset<=0 then exit;

  if FormatVersion=cfClassic then
    ReadDocumentInt(offset,data,lb,lbf,lbs)
  else
    ReadDocumentInt_v2(offset,data,lb2,lbf2,lbs2);
end;

procedure T1CContainer.FillFilesList(sl: TStrings);
var
  i:integer;
begin
  sl.BeginUpdate;

  sl.Clear;
  for i:=0 to Length(FFilesList)-1 do
    sl.AddObject(FFilesList[i].Name,Pointer(i));

  sl.EndUpdate;
end;

function T1CContainer.GetContainerV1Size(): int64;
  procedure lScanDocumentInt(offset: integer);
  var
    BlockHeader:T1CContainerBlockHeaderRec;
    NextOffset:integer;
  begin
    ReadBlock(offset,BlockHeader,false);
    NextOffset:=StrToInt('$'+BlockHeader.NextBlockOffset);
    while NextOffset<>$7FFFFFFF do begin
      ReadBlock(NextOffset,BlockHeader,false);
      NextOffset:=StrToIntDef('$'+BlockHeader.NextBlockOffset,-1);
    end;
  end;

var
  i:integer;
begin
  if Header.FreeBlockOffset<>$7FFFFFFF then
    lScanDocumentInt(Header.FreeBlockOffset);

  for i:=0 to DocumentsCount()-1 do begin
    lScanDocumentInt(Files[i].BlockOffset);
  end;
  Result:=FLastBlockOffset+FLastBlockSize;
end;

procedure T1CContainer.SetStub(st: TStream);
var
  buf:AnsiString;
begin
  if FormatVersion<>cfNew then exit;
  if DocumentsCount>0 then raise Exception.Create('Container is not empty');
  SetLength(buf,FStream.Size-Fv1StubSize);
  FStream.Position:=Fv1StubSize;
  FStream.Read(buf[1],Length(buf));
  FStream.Position:=0;
  if (st=nil)or(st.Size=0) then begin
    Fv1StubSize:=0;
    SetLength(Fv1Stub,0);
  end else begin
    Fv1StubSize:=st.Size;
    SetLength(Fv1Stub,Fv1StubSize);
    st.Position:=0;
    st.Read(Fv1Stub[0],Fv1StubSize);
    FStream.Write(Fv1Stub[0],Fv1StubSize);
  end;
  FStream.Write(buf[1],Length(buf));
  FStream.Size:=FStream.Position;
end;

procedure T1CContainer.ReadDocumentInt(offset: UInt32; data: TStream; out
  LastBlock: UInt32; out LastBlockFill: integer; out LastBlockSize: integer);
var
  bh:T1CContainerBlockHeaderRec;
  buf:AnsiString;
  CurPos:Int64;
  DocSize:integer;
  NextBlock:Int64;
begin
  FillChar(bh,SizeOf(bh),0);
  ReadBlock(offset,bh,false);
  if bh.NextBlockOffset[0]=#0 then begin;
    LastBlock:=offset;
    LastBlockFill:=0;
    LastBlockSize:=0;
    exit;
  end;
  DocSize:=StrToInt64('$'+bh.DocumentSize);
  CurPos:=0;
  LastBlock:=offset;
  LastBlockFill:=0;
  LastBlockSize:=StrToInt('$'+bh.BlockSize);
  while CurPos<DocSize do begin
    buf:=ReadBlock(LastBlock,bh,true);
    if buf='' then exit;
    LastBlockSize:=StrToInt('$'+bh.BlockSize);
    LastBlockFill:=Min(DocSize-CurPos,LastBlockSize);
    data.Write(buf[1],LastBlockFill);
    inc(CurPos,LastBlockFill);
    if LastBlockFill<LastBlockSize then
      exit;
    NextBlock:=StrToInt64('$'+bh.NextBlockOffset);
    if NextBlock<>MaxInt then
      LastBlock:=NextBlock;
  end;

end;

procedure T1CContainer.ReadDocumentInt_v2(offset: int64; data: TStream; out
  LastBlock: int64; out LastBlockFill: int64; out LastBlockSize: int64);
var
  bh:T1CContainerBlockHeaderRec_v2;
  buf:AnsiString;
  CurPos:int64;
  DocSize:int64;
  NextBlock:int64;
begin
  FillChar(bh,SizeOf(bh),0);
  ReadBlock_v2(offset,bh,false);
  if bh.NextBlockOffset[0]=#0 then begin
    LastBlock:=offset;
    LastBlockFill:=0;
    LastBlockSize:=0;
    exit;
  end;
  DocSize:=StrToInt64('$'+bh.DocumentSize);
  CurPos:=0;
  LastBlock:=offset;
  LastBlockFill:=0;
  LastBlockSize:=StrToInt64('$'+bh.BlockSize);
  while CurPos<DocSize do begin
    buf:=ReadBlock_v2(LastBlock,bh,true);
    if buf='' then exit;
    LastBlockSize:=StrToInt64('$'+bh.BlockSize);
    LastBlockFill:=Min(DocSize-CurPos,LastBlockSize);
    data.Write(buf[1],LastBlockFill);
    inc(CurPos,LastBlockFill);
    if LastBlockFill<LastBlockSize then
      exit;
    NextBlock:=StrToInt64('$'+bh.NextBlockOffset);
    if NextBlock<>Int64(-1) then
      LastBlock:=NextBlock;
  end;

end;

{ T1CContainerBlockHeaderRec }

procedure T1CContainerBlockHeaderRec.Init(_DocSize,_BlockSize,_NextBlock:integer);
var
  s:AnsiString;
begin
  crlf1:=#13#10;
  space1:=' ';
  space2:=' ';
  space3:=' ';
  crlf2:=#13#10;
  s:=LowerCase(IntToHex(_DocSize,8));
  move(s[1],DocumentSize,8);
  s:=LowerCase(IntToHex(_BlockSize,8));
  move(s[1],BlockSize,8);
  s:=LowerCase(IntToHex(_NextBlock,8));
  move(s[1],NextBlockOffset,8);
end;

procedure T1CContainerBlockHeaderRec.SetDocSize(_DocSize: integer);
var
  s:AnsiString;
begin
  s:=LowerCase(IntToHex(_DocSize,8));
  move(s[1],DocumentSize,8);
end;

procedure T1CContainerBlockHeaderRec.SetNextBlock(_NextBlock: integer);
var
  s:AnsiString;
begin
  s:=LowerCase(IntToHex(_NextBlock,8));
  move(s[1],NextBlockOffset,8);
end;

{ T1CContainerBlockHeaderRec_v2 }

procedure T1CContainerBlockHeaderRec_v2.Init(_DocSize,_BlockSize,_NextBlock:int64);
var
  s:AnsiString;
begin
  crlf1:=#13#10;
  space1:=' ';
  space2:=' ';
  space3:=' ';
  crlf2:=#13#10;
  s:=UpperCase(IntToHex(_DocSize,16));
  move(s[1],DocumentSize,16);
  s:=UpperCase(IntToHex(_BlockSize,16));
  move(s[1],BlockSize,16);
  s:=UpperCase(IntToHex(_NextBlock,16));
  move(s[1],NextBlockOffset,16);
end;

procedure T1CContainerBlockHeaderRec_v2.SetDocSize(_DocSize: int64);
var
  s:AnsiString;
begin
  s:=UpperCase(IntToHex(_DocSize,16));
  move(s[1],DocumentSize,16);
end;

procedure T1CContainerBlockHeaderRec_v2.SetNextBlock(_NextBlock: int64);
var
  s:AnsiString;
begin
  s:=UpperCase(IntToHex(_NextBlock,16));
  move(s[1],NextBlockOffset,16);
end;

function TestIsStream1CContainerBuf(const buf;TotalSize:Int64):boolean;
var
  hdr:P1CContainerHeader;
  bh:P1CContainerBlockHeaderRec;
  i,ds,bs:integer;

  function CheckHexInt(const v:THexInteger):boolean;
  var
    i:integer;
  begin
    result:=false;
    for i:=Low(v) to High(v) do
      if not (v[i] in ['0'..'9','a'..'f']) then exit;
    result:=true;
  end;

begin
  result:=false;
  if TotalSize<$2F then exit;
  hdr:=@buf;
  if hdr.FreeBlockOffset<=0 then exit;
  if hdr.DefaultBlockSize<=0 then exit;
  if hdr.ContainerVersion<=0 then exit;
  if hdr.reserved<>0 then exit;
  bh:=Pointer(PtrUInt(@buf)+SizeOf(hdr^));
  if bh.crlf1<>#$0d#$0a then exit;
  if not CheckHexInt(bh.DocumentSize) then exit;
  if bh.space1<>' ' then exit;
  if not CheckHexInt(bh.BlockSize) then exit;
  if bh.space2<>' ' then exit;
  if not CheckHexInt(bh.NextBlockOffset) then exit;
  if bh.space3<>' ' then exit;
  if bh.crlf2<>#$0d#$0a then exit;
  bs:=StrToInt('$'+bh.BlockSize);
  if (bs<=0)or((bs+$2f)>TotalSize) then exit;
  i:=StrToInt('$'+bh.NextBlockOffset);
  if (i<>$7fffffff)and((i<=0)or((i+$1f)>=TotalSize)) then exit;
  ds:=StrToInt('$'+bh.DocumentSize);
  if (ds<=0)or((ds+$2f)>TotalSize)or((ds mod (4*3))<>0) then exit;
  result:=true;
end;

function TestIsStream1CContainerBuf_v2(const buf; TotalSize: Int64): boolean;
var
  hdr:P1CContainerHeader_v2;
  bh:P1CContainerBlockHeaderRec_v2;
  ds,bs:integer;
  i:int64;

  function CheckHexInt(const v:THexInteger64):boolean;
  var
    i:integer;
  begin
    result:=false;
    for i:=Low(v) to High(v) do
      if not (v[i] in ['0'..'9','a'..'f','A'..'F']) then exit;
    result:=true;
  end;

begin
  result:=false;
  if TotalSize<(SizeOf(T1CContainerHeader_v2)+SizeOf(T1CContainerBlockHeaderRec_v2)) then exit;
  hdr:=@buf;
  if (hdr.FreeBlockOffset<-1)or(hdr.FreeBlockOffset>TotalSize) then exit;
  if hdr.DefaultBlockSize<=0 then exit;
  if hdr.ContainerVersion<0 then exit;
  if hdr.reserved<>0 then exit;
  bh:=Pointer(PtrUInt(@buf)+SizeOf(hdr^));
  if bh.crlf1<>#$0d#$0a then exit;
  if not CheckHexInt(bh.DocumentSize) then exit;
  if bh.space1<>' ' then exit;
  if not CheckHexInt(bh.BlockSize) then exit;
  if bh.space2<>' ' then exit;
  if not CheckHexInt(bh.NextBlockOffset) then exit;
  if bh.space3<>' ' then exit;
  if bh.crlf2<>#$0d#$0a then exit;
  bs:=StrToInt('$'+bh.BlockSize);
  if (bs<=0)or((bs+$2f)>TotalSize) then exit;
  i:=StrToInt('$'+bh.NextBlockOffset);
  if ((i<-1)or((i+$1f)>=TotalSize)) then exit;
  ds:=StrToInt('$'+bh.DocumentSize);
  if (ds<0)or((ds+$2f)>TotalSize)or((ds mod (4*3))<>0) then exit;
  result:=true;
end;

function TestIsStream1CContainer(st:TStream):boolean;
var
  buf:array of byte;
  r:integer;
begin
  SetLength(buf,SizeOf(T1CContainerHeader)+SizeOf(T1CContainerBlockHeaderRec));
  st.Seek(0,soBeginning);
  r:=st.Read(buf[0],Length(buf));
  if r<Length(buf) then begin
    result:=false;
    exit;
  end;
  result:=TestIsStream1CContainerBuf(buf[0],st.Size);
end;

function TestIsStream1CContainer_v2(st:TStream):boolean;
var
  buf:array of byte;
  r:integer;
begin
  SetLength(buf,SizeOf(T1CContainerHeader_v2)+SizeOf(T1CContainerBlockHeaderRec_v2));
//  st.Seek(0,soBeginning);
  r:=st.Read(buf[0],Length(buf));
  if r<Length(buf) then begin
    result:=false;
    exit;
  end;
  result:=TestIsStream1CContainerBuf_v2(buf[0],st.Size);
end;

var
  i,j:integer;
  c:byte;
begin
  DefaultStub:='';
  i:=0;
  while i<=high(stub_z) do begin
    c:=stub_z[i];inc(i);
    if (c and $80)<>0 then begin
      for j:=1 to (c and $7F) do DefaultStub:=DefaultStub+AnsiChar(stub_z[i]);
      inc(i);
    end else begin
      for j:=1 to c do begin
        DefaultStub:=DefaultStub+AnsiChar(stub_z[i]);
        inc(i);
      end;
    end;
  end;
end.
