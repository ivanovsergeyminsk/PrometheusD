unit Common.BitConverter;

interface
type
  ///  <summary>
  ///   Converts base data types to an array of bytes, and an array of bytes to base data types.
  ///  </summary>
  TBitConverter = class
  private
    class var FIsLittleEndian: boolean;
    class constructor Create;
  public
    ///  <summary>
    ///   Indicates the byte order ("endianness") in which data is stored
    ///   in this computer architecture
    ///  </summary>
    class property IsLittleEndian: boolean read FIsLittleEndian;
  public
    ///  <summary>
    ///   Returns the specified Boolean value as a byte array.
    ///  </summary>
    ///  <param name="value">A Boolean value.</param>
    ///  <returns>A byte array with length 1.</returns>
    class function GetBytes(value: boolean): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified Unicode character value as an array of bytes.
    ///  </summary>
    ///  <param name="value">A character to convert.</param>
    ///  <returns>An array of bytes with length 2.</returns>
    class function GetBytes(value: char): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returs the specified double-precission floating point value as an array of bytes.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 8.</returns>
    class function GetBytes(value: double): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified 16-bit signed integer value as an array of bytes.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 2.</returns>
    class function GetBytes(value: int16): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified 32-bit signed integer value as an array of bytes.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 4.</returns>
    class function GetBytes(value: int32): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified 64-bit signed integer value as an array of bytes.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 8.</returns>
    class function GetBytes(value: int64): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified single-precision floating point value as an array of bytes.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 4.</returns>
    class function GetBytes(value: single): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified 16-bit unsigned integer value as an array of bytes.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 2.</returns>
    class function GetBytes(value: uInt16): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified 32-bit unsigned integer value as an array of byte.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 4.</returns>
    class function GetBytes(value: uInt32): TArray<byte>; overload; static;
    ///  <summary>
    ///   Returns the specified 64-bit unsigned integer value as an array of byte.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>An array of bytes with length 8.</returns>
    class function GetBytes(value: uInt64): TArray<byte>; overload; static;
    ///  <summary>
    ///   Converts the specified double-precision floating point number to a 64-bit signed integer.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>A 64-bit signed integer whose value is equivalent to value.</returns>
    class function DoubleToInt64Bits(value: double): Int64; static;
    ///  <summary>
    ///   Converts the specified 64-bit signed integer to a double-precision floating point number.
    ///  </summary>
    ///  <param name="value">The number to convert.</param>
    ///  <returns>A double-precision floating point number whose value is equivalent to value.</returns>
    class function Int64BitsToDouble(value: int64): double; static;
    ///  <summary>
    ///   Returns a Boolean value converted from the byte at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">AByte array.</param>
    ///  <param name="startIndex">The index of the byte within value.</param>
    ///  <returns>True if the byte at startIndex in value is nonzero; otherwise, false.</returns>
    class function ToBoolean(value: TArray<byte>; startIndex: integer = 0): boolean; static;
    ///  <summary>
    ///   Returns a Unicode character converted from two bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A character formed by two bytes beginning at startIndex.</returns>
    class function ToChar(value: TArray<byte>; startIndex: integer = 0): Char; static;
    ///  <summary>
    ///   Returns a double-precision floating point number converted from eight bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of byte.</param>
    ///  <param name="startIndex">The startng position within value.</param>
    ///  <returns>A double precision floating point number formed by eight bytes beginning at startIndex.</returns>
    class function ToDouble(value: TArray<byte>; startIndex: integer = 0): double; static;
    ///  <summary>
    ///    Returns a 16-bit signed integer converted from two bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A 16-bit signed integer formed by two bytes beginning at startIndex.</returns>
    class function ToInt16(value: TArray<byte>; startIndex: integer = 0): int16; static;
    ///  <summary>
    ///    Returns a 32-bit signed integer converted from 4 bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A 32-bit signed integer formed by 4 bytes beginning at startIndex.</returns>
    class function ToInt32(value: TArray<byte>; startIndex: integer = 0): int32; static;
    ///  <summary>
    ///    Returns a 64-bit signed integer converted from 8 bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A 64-bit signed integer formed by 8 bytes beginning at startIndex.</returns>
    class function ToInt64(value: TArray<byte>; startIndex: integer = 0): int64; static;
    ///  <summary>
    ///    Returns a single-precision floating point number converted from 4 bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A single-precision floating point number formed by 4 bytes beginning at startIndex.</returns>
    class function ToSingle(value: TArray<byte>; startIndex: integer = 0): single; static;
    ///  <summary>
    ///    Converts the numeric value of each element of a specified array of bytes to its equivalent hexadecimal string representation.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <returns>A string of hexadecimal pairs separated by hyphens, where each pair represents the corresponding element in value; for example, "7F-2C-4A-00".</returns>
    class function ToString(value: TArray<byte>): string; reintroduce; overload; static;
    ///  <summary>
    ///    Converts the numeric value of each element of a specified subarray of bytes to its equivalent hexadecimal string representation.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A string of hexadecimal pairs separated by hyphens, where each pair represents the corresponding element in a subarray of value; for example, "7F-2C-4A-00".</returns>
    class function ToString(value: TArray<byte>; startIndex: integer): string; reintroduce; overload; static;
    ///  <summary>
    ///    Converts the numeric value of each element of a specified subarray of bytes to its equivalent hexadecimal string representation.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <param name="ALength">The number of array elements in value to convert.</param>
    ///  <returns>A string of hexadecimal pairs separated by hyphens, where each pair represents the corresponding element in a subarray of value; for example, "7F-2C-4A-00".</returns>
    class function ToString(value: TArray<byte>; startIndex: integer; ALength: integer): string; reintroduce; overload; static;
    ///  <summary>
    ///    Returns a 16-bit unsigned integer converted from 2 bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A 16-bit unsigned integer formed by 2 bytes beginning at startIndex.</returns>
    class function ToUInt16(value: TArray<byte>; startIndex: integer = 0): uInt16; static;
    ///  <summary>
    ///    Returns a 32-bit unsigned integer converted from 4 bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A 32-bit unsigned integer formed by 4 bytes beginning at startIndex.</returns>
    class function ToUInt32(value: TArray<byte>; startIndex: integer = 0): uInt32; static;
    ///  <summary>
    ///    Returns a 64-bit unsigned integer converted from 8 bytes at a specified position in a byte array.
    ///  </summary>
    ///  <param name="value">An array of bytes.</param>
    ///  <param name="startIndex">The starting position within value.</param>
    ///  <returns>A 64-bit unsigned integer formed by 8 bytes beginning at startIndex.</returns>
    class function ToUInt64(value: TArray<byte>; startIndex: integer = 0): uInt64; static;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections, System.Classes;

resourcestring
  VALUE_IS_NIL                                             = 'value is nil.';
  STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1           = 'startIndex is less than zero or greater than the length of value minus 1';
  STARTINDEX_EQUALS_LENGTH_MINUS_1                         = 'startIndex equals the length of value minus 1.';
  STARTINDEX_GREATER_EQUALS_MINUS_7_OR_LESS_EQUALS_MINUS_1 = 'startIndex is greater than or equal to the length of value minus 7, and is less than or equal to the length of value minus 1.';
  STARTINDEX_GREATER_EQUALS_MINUS_3_OR_LESS_EQUALS_MINUS_1 = 'startIndex is greater than or equal to the length of value minus 3, and is less than or equal to the length of value minus 1.';
  STARTINDEX_OR_ALENGTH_LESS_ZERO                          = 'startIndex or ALength is less than zero.';
  STARTINDEX_GREATER_ZERO_OR_GERATER_EQUAL_LENGTH          = 'startIndex is greater than zero and is greater than or equal to the length of value.';
  COMBINATION_STARTINDEX_ALENGTH                           = 'The combination of startIndex and ALength does not specify a position within value; that is, the startIndex parameter is greater than the length of value minus the ALength parameter.';

const
  DASH = '-';
{ TBitConverter }

class constructor TBitConverter.Create;
var
  i: integer;
  iBytes: array[0..3] of byte absolute i;
begin
  i := 1;
  TBitConverter.FIsLittleEndian := iBytes[0] = 1;
end;

class function TBitConverter.DoubleToInt64Bits(value: double): Int64;
var
  vResult: int64 absolute value;
begin
  result := vResult;
end;

class function TBitConverter.GetBytes(value: int64): TArray<byte>;
var
  bValue: array[0..7] of Byte absolute value;
begin
  SetLength(result, 8);
  TArray.Copy<byte>(bValue,result,0,0,8);
end;

class function TBitConverter.GetBytes(value: char): TArray<byte>;
var
  VResult: TArray<byte>;
begin
  VResult := TEncoding.UTF8.GetBytes(value);
  if Length(VResult) < 2 then
    setLength(VResult, 2);

  result := VResult;
end;

class function TBitConverter.GetBytes(value: double): TArray<Byte>;
var
  bValue: array[0..7] of Byte absolute value;
begin
  SetLength(result, 8);
  TArray.Copy<byte>(bValue,result,0,0,8);
end;

class function TBitConverter.GetBytes(value: int16): TArray<byte>;
var
  bValue: array[0..1] of byte absolute value;
begin
  SetLength(result, 2);
  TArray.Copy<byte>(bValue, result,0,0,2);
end;

class function TBitConverter.GetBytes(value: int32): TArray<byte>;
var
  bValue: array[0..3] of byte absolute value;
begin
  SetLength(result, 4);
  TArray.Copy<byte>(bValue, result,0,0,4);
end;

class function TBitConverter.GetBytes(value: single): TArray<byte>;
var
  bValue: array[0..3] of byte absolute value;
begin
  SetLength(result, 4);
  TArray.Copy<byte>(bValue, result,0,0,4);
end;

class function TBitConverter.GetBytes(value: uInt16): TArray<byte>;
var
  bValue: array[0..1] of byte absolute value;
begin
  SetLength(result, 2);
  TArray.Copy<byte>(bValue, result,0,0,2);
end;

class function TBitConverter.GetBytes(value: uInt32): TArray<byte>;
var
  bValue: array[0..3] of byte absolute value;
begin
  SetLength(result, 4);
  TArray.Copy<byte>(bValue, result,0,0,4);
end;

class function TBitConverter.GetBytes(value: uInt64): TArray<byte>;
var
  bValue: array[0..7] of byte absolute value;
begin
  SetLength(result, 8);
  TArray.Copy<byte>(bValue, result,0,0,8);
end;

class function TBitConverter.GetBytes(value: boolean): TArray<byte>;
begin
  if value then
    result := [$01]
  else
    result := [$00];
end;

class function TBitConverter.Int64BitsToDouble(value: int64): double;
var
  vResult: double absolute value;
begin
  result := VResult;
end;

class function TBitConverter.ToBoolean(value: TArray<byte>;
  startIndex: integer): boolean;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  result := value[startIndex] > 0;
end;

class function TBitConverter.ToChar(value: TArray<byte>;
  startIndex: integer): Char;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if startIndex = length(value)-1 then
    raise EArgumentException.Create(STARTINDEX_EQUALS_LENGTH_MINUS_1);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  result := TEncoding.Unicode.GetChars(value, startIndex,2)[0];
end;

class function TBitConverter.ToDouble(value: TArray<byte>;
  startIndex: integer): double;
var
  vValue: array[0..7] of byte;
  VResult: double absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex >= length(value)-7) and
     (startIndex <= length(value)-1) then
    raise EArgumentException.Create(STARTINDEX_GREATER_EQUALS_MINUS_7_OR_LESS_EQUALS_MINUS_1);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,8);
  result := VResult;
end;

class function TBitConverter.ToInt16(value: TArray<byte>;
  startIndex: integer): int16;
var
  vValue: array[0..1] of byte;
  VResult: int16 absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if startIndex = length(value)-1 then
    raise EArgumentException.Create(STARTINDEX_EQUALS_LENGTH_MINUS_1);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,2);
  result := VResult;
end;

class function TBitConverter.ToInt32(value: TArray<byte>;
  startIndex: integer): int32;
var
  vValue: array[0..3] of byte;
  VResult: int32 absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex >= length(value)-3) and
     (startIndex <= length(value)-1) then
    raise EArgumentException.Create(STARTINDEX_GREATER_EQUALS_MINUS_3_OR_LESS_EQUALS_MINUS_1);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,4);
  result := VResult;
end;

class function TBitConverter.ToInt64(value: TArray<byte>;
  startIndex: integer): int64;
var
  vValue: array[0..7] of byte;
  VResult: int64 absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex >= length(value)-7) and
     (startIndex <= length(value)-1) then
    raise EArgumentException.Create(STARTINDEX_GREATER_EQUALS_MINUS_7_OR_LESS_EQUALS_MINUS_1);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,8);
  result := VResult;
end;

class function TBitConverter.ToSingle(value: TArray<byte>;
  startIndex: integer): single;
var
  vValue: array[0..3] of byte;
  VResult: single absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex >= length(value)-3) and
     (startIndex <= length(value)-1) then
    raise EArgumentException.Create(STARTINDEX_GREATER_EQUALS_MINUS_3_OR_LESS_EQUALS_MINUS_1);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,4);
  result := VResult;
end;

class function TBitConverter.ToString(value: TArray<byte>; startIndex,
  ALength: integer): string;
var
  text: TArray<byte>;
  sText: string;
  I: integer;
begin
 if Length(value) = 0 then
  raise EArgumentNilException.Create(VALUE_IS_NIL);

 if (startIndex < 0) or (ALength < 0)  then
  raise EArgumentOutOfRangeException.Create(STARTINDEX_OR_ALENGTH_LESS_ZERO);

 if (startIndex > 0) and (startIndex >= length(value)) then
  raise EArgumentOutOfRangeException.Create(STARTINDEX_GREATER_ZERO_OR_GERATER_EQUAL_LENGTH);

 if startIndex > length(value)-ALength then
  raise EArgumentException.Create(COMBINATION_STARTINDEX_ALENGTH);

 result := string.empty;
 setLength(text, ALength*2);
 BinToHex(value, startIndex, text, 0, ALength);
 sText := TEncoding.UTF8.GetString(text);

 I := 1;
 while I < length(sText) do begin
  result := result + sText[I]+sText[I+1];
  inc(I, 2);
  if I < length(sText) then
    result := result + DASH;
 end;
end;

class function TBitConverter.ToUInt16(value: TArray<byte>;
  startIndex: integer): uInt16;
var
  vValue: array[0..1] of byte;
  VResult: uInt16 absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  if startIndex = length(value)-1 then
    raise EArgumentException.Create(STARTINDEX_EQUALS_LENGTH_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,2);
  result := VResult;
end;

class function TBitConverter.ToUInt32(value: TArray<byte>;
  startIndex: integer): uInt32;
var
  vValue: array[0..3] of byte;
  VResult: uInt32 absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  if (startIndex >= length(value)-3) and (startIndex <= length(value)-1) then
    raise EArgumentException.Create(STARTINDEX_GREATER_EQUALS_MINUS_3_OR_LESS_EQUALS_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,4);
  result := VResult;
end;

class function TBitConverter.ToUInt64(value: TArray<byte>;
  startIndex: integer): uInt64;
var
  vValue: array[0..7] of byte;
  VResult: uInt64 absolute vValue;
begin
  if length(value) = 0 then
    raise EArgumentNilException.Create(VALUE_IS_NIL);

  if (startIndex < 0) or (startIndex > length(value)-1) then
    raise EArgumentOutOfRangeException.Create(STARTINDEX_LESS_ZERO_OR_GREATER_LENGTH_MINUS_1);

  if (startIndex >= length(value)-7) and (startIndex <= length(value)-1) then
    raise EArgumentException.Create(STARTINDEX_GREATER_EQUALS_MINUS_7_OR_LESS_EQUALS_MINUS_1);

  TArray.Copy<byte>(value, vValue, startIndex,0,8);
  result := VResult;
end;

class function TBitConverter.ToString(value: TArray<byte>;
  startIndex: integer): string;
begin
  result := TBitConverter.ToString(value, startIndex, length(value)-startIndex);
end;

class function TBitConverter.ToString(value: TArray<byte>): string;
begin
  result := TBitConverter.ToString(value, 0, length(value));
end;

end.
