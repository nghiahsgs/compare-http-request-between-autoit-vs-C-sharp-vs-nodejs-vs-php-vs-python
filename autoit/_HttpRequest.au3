#include-once
#include <WinHttp.au3> ;Thanks [@ProAndy ] [Trancexx] autoitscript.com
#include <Array.au3>


#cs Bao gồm các hàm chính
	_HttpRequest
	_HttpRequest_ErrorNotify                     Bật tắt thông báo lỗi ở Console
	_HttpRequest_NewSession                   Xoá tất cả Cookies và Handles mà WinHttp đã sử dụng
	_HttpRequest_ReadWriteStatus             Chi tiết về lượng data gửi nhận khi download và upload
	_HttpRequest_Authorization                  Thực hiện Authorization khi nhận Status 401
	_HttpRequest_SetOption                       Cài đặt Proxy, Timeout, phím tắt dừng quá trình Upload, set Option En/Disable Redirects
	_URIEncode                                         Mã hoá chuỗi URL
	_URIDecode                                         Giải mã chuỗi URL
	_URLDecode                                        Giải mã source HTML có những dạng như \u2A21, \x2121, &#x1234; ... Mặc định của Escape Character là \u
	_GetCookie                                          Tách lấy Cookie từ Response Header
	_GetLocation_Redirect                          Tách Location từ Response Header
	_GetFileInfos                                       Trả về mảng gồm: [0] Tên, [1] Kiểu (Content-Type), [2] Data của 1 file. Dùng khi Upload.
	_WinHttpBoundaryGenerator                 Tạo chuỗi Boundary khi Upload
	_FileWrite_Test                                   Ghi giá trị trả về ra 1 file
	_B64Encode                                         Mã hoá Base64 đơn giản
	_B64Decode                                        Giải mã Base64 đơn giản
	_TimeStampUNIX                                Tạo đóng dấu Timetamp theo giờ hệ thống
#ce


#cs Các hàm chưa hoàn thành xong
	_HttpRequest_CreateDataFormSimple   Tạo nhanh biểu mẫu Data2Send đơn giản cho việc Upload
	_HttpRequest_ContentDisposition_Convert    Hàm giúp chuyển đổi nhanh Data của POST Content-Type: multipart/form-data từ LHH sang code autoit
#ce


#cs Note
	*** WINHTTP_DISABLE_REDIRECTS: Automatic redirection is disabled when sending requests with WinHttpSendRequest. If automatic redirection is disabled, an application must register a callback function in order for Passport authentication to succeed.
	*** Authentication in WinHTTP: https://msdn.microsoft.com/en-us/library/windows/desktop/aa383144(v=vs.85).aspx
	__WinHttpSetCredentials($g___hRequest, $WINHTTP_NO_ADDITIONAL_HEADERS, $WINHTTP_NO_REQUEST_DATA, $sCredName, $sCredPass)
	_WinHttpAddRequestHeaders($g___hRequest, "Cookie: -1", $WINHTTP_ADDREQ_FLAG_REPLACE)
	_WinHttpSetOption($g___hRequest, $WINHTTP_OPTION_AUTOLOGON_POLICY, $WINHTTP_AUTOLOGON_SECURITY_LEVEL_LOW)
	_WinHttpSetOption($g___hRequest, $WINHTTP_OPTION_SECURE_PROTOCOLS, 168) ;$WINHTTP_FLAG_SECURE_PROTOCOL_ALL
	_WinHttpSetOption($g___hRequest, $WINHTTP_OPTION_SERVER_CERT_CONTEXT, Null)
#ce



Global $g___hOpen, $g___hConnect, $g___hRequest
;------------------------------------------------------------------------------------
Global $sHotKeyCancelReadWrite = '', $g___iTimeOut = '', $g___iProxy = ''
Global $Z_Buffer, $Z_BufferMemory, $Z_BufferPtr, $Z_Alloc_Callback, $Z_Free_Callback
Global $Z_InfInit, $Z_InfInit2, $Z_Inf, $Z_InfEnd, $Z_DefInit, $Z_DefInit2, $Z_Def, $Z_DefEnd, $Z_DefBound
;------------------------------------------------------------------------------------
Global Const $def___sChr64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
Global Const $def___aChr64 = StringSplit($def___sChr64, "", 2)
Global Const $def___sPadding = '='
Global $g___sChr64 = $def___sChr64
Global $g___aChr64 = $def___aChr64
Global $g___sPadding = $def___sPadding
;------------------------------------------------------------------------------------
Global Const $g___PortFlag[2][2] = [[80, 443], [0, 0x800000]]
Global $g___iUserAgent = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.89 Safari/537.36'
Global $g___TotalLoops = -1, $g___PosLoop = 0, $g___NumberOfBytesPerRequest = 8192, $g___DataSizeBytes = -1
Global $g___sUserName, $g___sPassword
Global $g___MaskFunc = 0
Global $g___HeaderInfoLevel = Default
Global $g___CancelReadWrite = False
Global $g___Disable_Redirects = True
Global $g___Authorization = False
Global $g___ErrorNotify = True
Global $g___Async = Default
Global $g___URLConnect = ''
Global $g___User32DLL = DllOpen("user32.dll")
DllOpen("user32.dll")
OnAutoItExitRegister('__WinHttpCloseHandle')





Func _HttpRequest_ErrorNotify($___ErrorNotify = True)
	$g___ErrorNotify = $___ErrorNotify
EndFunc


Func _HttpRequest_CreateDataFormSimple($a_Content_Disposition)
	Local $sBoundary = _WinHttpBoundaryGenerator()
	Local $2CRLF = @CRLF & @CRLF
	Local $sDataToSend = $sBoundary & @CRLF
	If IsArray($a_Content_Disposition) And UBound($a_Content_Disposition, 2) = 2 Then
		Local $__uBound = UBound($a_Content_Disposition) - 1
		For $i = 0 To $__uBound
			$sDataToSend &= 'Content-Disposition: form-data; name=' & $a_Content_Disposition[$i][0] & $2CRLF & $a_Content_Disposition[$i][1]
			If $i < $__uBound Then $sDataToSend &= @CRLF & $sBoundary & @CRLF
		Next
	EndIf
	Return StringRegExpReplace($sDataToSend, '(data; name=)(\w+)', '$1"$2"') & @CRLF & $sBoundary & '--'
EndFunc


Func _HttpRequest_ContentDisposition_Convert($sData)
	Local $KQ = '', $aaaData
	Local $Boundary = StringRegExp($sData, '(?m)^(---+\d+)$', 1)
	If @error Then Return SetError(1, '', False)
	$Boundary = $Boundary[0]
	Local $aData = StringSplit($sData, $Boundary, 1)
	For $i = 1 To $aData[0]
		If $aData[$i] = '' Then ContinueLoop
		$aaaData = StringSplit(StringStripWS($aData[$i], 3), @CRLF & @CRLF, 1)
		If $aaaData[0] = 1 Then ContinueLoop
		If StringInStr($aaaData[1], @CRLF, 1, 1) Then
			$aaaData[1] = StringReplace(StringReplace($aaaData[1], @CRLF, "' & @CRLF & '", 1, 1), 'Content-Disposition: form-data; name=', '', 1, 1)
		Else
			$aaaData[1] = StringTrimRight(StringReplace($aaaData[1], 'Content-Disposition: form-data; name="', '', 1, 1), 1)
		EndIf
		$KQ &= "['" & $aaaData[1] & "', " & "'" & $aaaData[2] & "'], "
	Next
	$KQ = 'Local $aDispos = [' & StringTrimRight($KQ, 2) & ']'
	ConsoleWrite('!Converted' & @CRLF)
	ClipPut($KQ)
	Return $KQ
EndFunc


Func _HttpRequest_NewSession()
	If $g___hConnect Then _WinHttpCloseHandle($g___hConnect)
	If $g___hOpen Then _WinHttpCloseHandle($g___hOpen)
	$g___hConnect = ''
	$g___hOpen = ''
EndFunc


Func _HttpRequest_ReadWriteStatus()
	Local $aReturn = [$g___PosLoop, $g___TotalLoops, $g___NumberOfBytesPerRequest, $g___DataSizeBytes]
	Return $aReturn
EndFunc


Func _HttpRequest_SetOption($__Proxy = '', $__TimeOut = '', $__sHotKeyCancelReadWrite = '', $__Disable_Redirects = True, $__Async = False)
	$g___iProxy = ($__Proxy And $__Proxy <> Default ? $__Proxy : '')
	$g___iTimeOut = ($__TimeOut And $__TimeOut <> Default ? $__TimeOut : '')
	$g___Disable_Redirects = ($__Disable_Redirects = False Or $__Disable_Redirects <> Default ? False : True)
	$g___Async = ($__Async = False ? Default : $WINHTTP_FLAG_ASYNC)
	HotKeySet(($__sHotKeyCancelReadWrite And $__sHotKeyCancelReadWrite <> Default) ? $__sHotKeyCancelReadWrite : '', '__WinHttpCancelReadWrite')
EndFunc


Func _HttpRequest_Authorization($___sUserName, $___sPassword)
	$g___Authorization = True
	$g___sUserName = $___sUserName
	$g___sPassword = $___sPassword
EndFunc


Func _HttpRequest($iReturn, $sURL, $sDataToSend = '', $sCookie = '', $sReferrer = '', $sAdditional_Headers = '', $sOVerb = '', $ptCallBackFunc_ReadWrite = '', $ptAdditionalFunc_BeforeSendRequest = '', $ptAdditionalFunc_AfterSendRequest = '')
	Local $customPort = StringRegExp($sURL, '^(https?:\/\/[^\/].*?):(\d+)(\/?.*?)$', 3)
	If @error Then
		$customPort = ''
	Else
		$sURL = $customPort[0] & $customPort[2]
		$customPort = $customPort[1]
	EndIf
	;-------------------------------------------------
	Local $aURL = StringRegExp($sURL, '^http(s?)://([^/]+)(.*?)$', 3)
	If @error Then Return SetError(1, __WinHttpErrorNotify('_HttpRequest', '$sURL'), '$sURL: Error')
	;-------------------------------------------------
	Local $aReturn = StringRegExp($iReturn, '^([+-]?)(\d+)(\*?)$', 3)
	If @error Then Return SetError(2, __WinHttpErrorNotify('_HttpRequest', '$iReturn'), '$iReturn: Error')
	Local $iMode = $aReturn[0]
	Local $forceEnRedirect = $aReturn[2]
	$iReturn = $aReturn[1]
	;-------------------------------------------------
	Local $rData[2], $iError = 0, $vContentLength = 0, $vContentType = '', $vCaseSendRequest = 0
	Local $sVerb = ($sOVerb ? $sOVerb : ($sDataToSend ? "POST" : "GET"))
	Local $SSL = ($aURL[0] ? 1 : 0)
	;-------------------------------------------------
	If $g___iProxy Then
		$g___hOpen = _WinHttpOpen($g___iUserAgent, 3, $g___iProxy, Default, $g___Async)
	Else
		If Not $g___hOpen Then $g___hOpen = _WinHttpOpen($g___iUserAgent, Default, Default, Default, $g___Async)
	EndIf
	If $g___iTimeOut Then _WinHttpSetTimeouts($g___hOpen, Default, $g___iTimeOut, $g___iTimeOut, $g___iTimeOut)
	;-------------------------------------------------
	If Not $g___hConnect Or $g___URLConnect <> $aURL[1] Then
		$g___URLConnect = $aURL[1]
		If $g___hConnect Then _WinHttpCloseHandle($g___hConnect)
		$g___hConnect = _WinHttpConnect($g___hOpen, $aURL[1], $customPort ? $customPort : $g___PortFlag[0][$SSL])
	EndIf
	;-------------------------------------------------
	$g___hRequest = _WinHttpOpenRequest($g___hConnect, $sVerb, $aURL[2], Default, $sReferrer, Default, $g___PortFlag[1][$SSL])
	;-------------------------------------------------
	_WinHttpSetOption($g___hRequest, 118, 3) ;OPTION_DECOMPRESSION = DECOMPRESSION_FLAG_ALL
	;-------------------------------------------------
	If $iReturn = 1 And $g___Disable_Redirects = True And Not $forceEnRedirect Then _WinHttpSetOption($g___hRequest, 63, 2)
	If $aURL[0] Then _WinHttpSetOption($g___hRequest, 31, 13056) ;OPTION_SECURITY_FLAGS = SECURITY_FLAG_IGNORE_ALL
	;-------------------------------------------------
	If IsFunc($ptAdditionalFunc_BeforeSendRequest) Then $ptAdditionalFunc_BeforeSendRequest()
	;-------------------------------------------------
	If $sAdditional_Headers Then
		Local $aAddition = StringSplit($sAdditional_Headers, '|')
		For $i = 1 To $aAddition[0]
			If StringInStr($aAddition[$i], 'Content-Type:', 0, 1, 1, 20) Then
				$vContentType = $aAddition[$i]
				ContinueLoop
			EndIf
			_WinHttpAddRequestHeaders($g___hRequest, $aAddition[$i])
		Next
	EndIf
	;-------------------------------------------------
	If $sCookie Then _WinHttpAddRequestHeaders($g___hRequest, "Cookie: " & $sCookie)
	;-------------------------------------------------
	If $sDataToSend Then
		Local $sBoundary = StringRegExp($sDataToSend, '(?m)^(-{10,}\w+)$', 1)
		If @error Then
			$vCaseSendRequest = 1
			_WinHttpSendRequest($g___hRequest, $vContentType ? $vContentType : 'Content-Type: application/x-www-form-urlencoded', $sDataToSend)
		Else
			$vCaseSendRequest = 2
			$sBoundary = $sBoundary[0]
			If Not StringRegExp($sDataToSend, '(?s)[\r\n]{1,2}' & $sBoundary & '-?-?$') Then $sDataToSend &= @CRLF & $sBoundary & '--'
			_WinHttpSendRequest($g___hRequest, $vContentType ? $vContentType : 'Content-Type: multipart/form-data; boundary=' & StringTrimLeft($sBoundary, 2), Default, StringLen($sDataToSend))
			_WinHttpWriteData_Ex($g___hRequest, $sDataToSend, $ptCallBackFunc_ReadWrite)
			If @error Then $iError = @error
		EndIf
	Else
		_WinHttpSendRequest($g___hRequest, $vContentType)
	EndIf
	;-------------------------------------------------
	If $iError = 0 Then
		_WinHttpReceiveResponse($g___hRequest)
		If @error Then
			$iError = 3
		Else
			;-------------------------------------------------
			If $g___Authorization Then
				Switch _WinHttpQueryHeaders($g___hRequest, $WINHTTP_QUERY_STATUS_CODE)
					Case 401, 407
						Local $iSupportedSchemes, $iFirstScheme, $iAuthTarget
						If _WinHttpQueryAuthSchemes($g___hRequest, $iSupportedSchemes, $iFirstScheme, $iAuthTarget) Then
							_WinHttpSetCredentials($g___hRequest, $iAuthTarget, $iFirstScheme, $g___sUserName, $g___sPassword)
							Switch $vCaseSendRequest
								Case 0
									_WinHttpSendRequest($g___hRequest, $vContentType)
								Case 1
									_WinHttpSendRequest($g___hRequest, $vContentType ? $vContentType : 'Content-Type: application/x-www-form-urlencoded', $sDataToSend)
								Case 2
									_WinHttpSendRequest($g___hRequest, $vContentType ? $vContentType : 'Content-Type: multipart/form-data; boundary=' & StringTrimLeft($sBoundary, 2), Default, StringLen($sDataToSend))
									_WinHttpWriteData_Ex($g___hRequest, $sDataToSend, $ptCallBackFunc_ReadWrite)
									If @error Then $iError = @error
							EndSwitch
							_WinHttpReceiveResponse($g___hRequest)
							If @error Then $iError = -10
						EndIf
				EndSwitch
			EndIf
			;-------------------------------------------------
			If $iError <> -10 Then
				If $iReturn = 1 Or $iReturn > 3 Then
					$rData[0] = _WinHttpQueryHeaders($g___hRequest, $g___HeaderInfoLevel)
					If @error Then $iError = 4
					If $iError = 0 And $iMode == '-' And $iReturn = 1 Then
						$rData[0] = _GetCookie($rData[0])
						If @error Then $iError = 5
					EndIf
				EndIf
				If $iReturn > 1 Then
					$vContentLength = _WinHttpQueryHeaders($g___hRequest, $WINHTTP_QUERY_CONTENT_LENGTH)
					If $vContentLength Then
						$g___DataSizeBytes = $vContentLength
						$g___TotalLoops = Ceiling($vContentLength / $g___NumberOfBytesPerRequest)
					EndIf
					If $g___DataSizeBytes > 2000000000 Then
						$iError = -3
					Else
						Local $bData = _WinHttpReadData_Ex($g___hRequest, $ptCallBackFunc_ReadWrite)
						If @error Then
							$iError = @error
						Else
							If $iMode == '-' Then
								$rData[1] = $bData
							Else
								If StringRegExp(BinaryMid($bData, 1, 1), '(?i)0x(1F|08|8B)') Or $iMode == '+' Then $bData = __ZL_GZUncompress($bData)
								$rData[1] = BinaryToString($bData, 4)
							EndIf
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
	EndIf
	;-------------------------------------------------
	If IsFunc($ptAdditionalFunc_AfterSendRequest) And $iError = 0 Then $ptAdditionalFunc_AfterSendRequest()
	;-------------------------------------------------
	$g___PosLoop = 0
	$g___TotalLoops = -1
	$g___DataSizeBytes = -1
	$g___MaskFunc = 0
	$g___NumberOfBytesPerRequest = 8192
	$g___Async = Default
	$g___Authorization = False
	$g___CancelReadWrite = False
	$g___HeaderInfoLevel = Default
	_WinHttpCloseHandle($g___hRequest)
	If Number($sCookie) = -1 Then _HttpRequest_NewSession()
	;-------------------------------------------------
	Switch $iReturn
		Case 1
			Return SetError($iError, __WinHttpErrorNotify('_HttpRequest', $iError), $rData[0])
		Case 2, 3
			Return SetError($iError, __WinHttpErrorNotify('_HttpRequest', $iError), $rData[1])
		Case Else
			Return SetError($iError, __WinHttpErrorNotify('_HttpRequest', $iError), $rData)
	EndSwitch
EndFunc


Func _WinHttpBoundaryGenerator()
	Local $sData = ""
	For $i = 1 To 12
		$sData &= Random(1, 9, 1)
	Next
	Return ('-----------------------------' & $sData)
EndFunc


Func _URIEncode($sData) ; [Prog@ndy] autoitscript.com
	Local $aData = StringSplit(BinaryToString(StringToBinary($sData, 4), 1), "")
	Local $nChar
	$sData = ""
	For $i = 1 To $aData[0]
		$nChar = Asc($aData[$i])
		Switch $nChar
			Case 45, 46, 48 To 57, 65 To 90, 95, 97 To 122, 126
				$sData &= $aData[$i]
			Case 32
				$sData &= "+"
			Case Else
				$sData &= "%" & Hex($nChar, 2)
		EndSwitch
	Next
	Return $sData
EndFunc


Func _URIDecode($sData) ; [Prog@ndy] autoitscript.com
	Local $aData = StringSplit(StringReplace($sData, "+", " ", 0, 1), "%")
	$sData = ""
	For $i = 2 To $aData[0]
		$aData[1] &= Chr(Dec(StringLeft($aData[$i], 2))) & StringTrimLeft($aData[$i], 2)
	Next
	Return BinaryToString(StringToBinary($aData[1], 1), 4)
EndFunc


Func _URLDecode($sData, $Escape_Character = '\u')
	Local $aSRE = StringRegExp($sData, '(?i)\Q' & $Escape_Character & '\E([[:xdigit:]]{2,4});?', 3)
	If @error Then Return SetError(1, __WinHttpErrorNotify('_URLDecode', 1), $sData)
	For $i = 0 To UBound($aSRE) - 1
		$sData = StringRegExpReplace($sData, '\Q' & $Escape_Character & $aSRE[$i] & '\E;?', ChrW(Int('0x' & $aSRE[$i])))
	Next
	If Not $sData Then Return SetError(2, __WinHttpErrorNotify('_URLDecode', 2), $sData)
	Return $sData
EndFunc


Func _GetCookie($sHeader, $Excluded_Values = '')
	If $sHeader == '' Then SetError(1, __WinHttpErrorNotify('_GetCookie', 1), '')
	If $Excluded_Values Then $Excluded_Values = '(?!' & StringRegExpReplace($Excluded_Values, '($|\|)', '=${1}') & ')'
	Local $__aRH = StringRegExp($sHeader, '(?im)^Set-Cookie:\s{0,1}' & $Excluded_Values & '([^=]+)=(?!deleted;)(.*)$', 3)
	If @error Or Not IsArray($__aRH) Then Return SetError(2, __WinHttpErrorNotify('_GetCookie', 2), '')
	Local $__sRH = '', $__uBound = UBound($__aRH)
	If Mod($__uBound, 2) Then Return SetError(3, __WinHttpErrorNotify('_GetCookie', 3), '')
	For $i = $__uBound - 2 To 0 Step -2
		If $__aRH[$i] == '' Then ContinueLoop
		$__sRH = $__aRH[$i] & '=' & $__aRH[$i + 1] & '; ' & $__sRH
		For $k = 0 To $i Step 2
			If $__aRH[$k] == $__aRH[$i] Then $__aRH[$k] = ''
		Next
	Next
	$__sRH = StringRegExpReplace($__sRH, '(?i)\s?(Path|Expires|Max-Age|Domain)=[^;]*(;| ;)', '')
	$__sRH = StringRegExpReplace($__sRH, '(?i);\s?(Secure; Httponly|Httponly|Secure)(;|$)', ';')
	Return $__sRH
EndFunc


Func _GetLocation_Redirect($__sHeader)
	If Not $__sHeader Then Return SetError(1, __WinHttpErrorNotify('_GetLocation_Redirect', 1), '')
	Local $__aRH = StringRegExp($__sHeader, '(?im)^Location:\s?(.+)$', 1)
	If @error Or Not IsArray($__aRH) Then Return SetError(2, __WinHttpErrorNotify('_GetLocation_Redirect', 2), '')
	Return $__aRH[0]
EndFunc


Func _GetFileInfos($sFilePath)
	If Not FileExists($sFilePath) Then Return SetError(1, __WinHttpErrorNotify('_GetFileInfos', 1), '')
	Local $sFileName = StringRegExp($sFilePath, '[\\\/]([^\\\/]+\.\w+)$', 1)
	If @error Then Return SetError(2, __WinHttpErrorNotify('_GetFileInfos', 2), '')
	Local $FileOpen = FileOpen($sFilePath, 16)
	If @error Then Return SetError(3, __WinHttpErrorNotify('_GetFileInfos', 3), '')
	Local $sFileData = FileRead($FileOpen)
	FileClose($FileOpen)
	Local $aReturn[4] = [$sFileName[0], __WinHttpMIMEType($sFileName[0]), BinaryToString($sFileData), BinaryLen($sFileData)]
	Return $aReturn
EndFunc


Func _FileWrite_Test($sData, $FilePath = @TempDir & '\Test.html')
	If Not $sData Then SetError(1, __WinHttpErrorNotify('_FileWrite_Test', 'Empty Data'), '')
	Local $l___hOpen = FileOpen($FilePath, 2 + (IsBinary($sData) ? 16 : 256))
	FileWrite($l___hOpen, $sData)
	FileClose($l___hOpen)
	ShellExecute($FilePath)
EndFunc


Func _TimeStampUNIX() ; Author ???
	Local $_aDate[3] = [@YEAR, @MON, @MDAY]
	Local $_aTime[3] = [@HOUR, @MIN, @SEC]
	If $_aDate[1] < 3 Then
		$_aDate[1] += 12
		$_aDate[0] -= 1
	EndIf
	Local $_aFactor = Int($_aDate[0] / 100)
	Local $aDaysDiff = Int($_aFactor / 4) - $_aFactor + $_aDate[2] + Int(1461 * ($_aDate[0] + 4716) / 4) + Int(153 * ($_aDate[1] + 1) / 5) - 2442110
	Return $aDaysDiff * 86400 + $_aTime[0] * 3600 + $_aTime[1] * 60 + $_aTime[2]
EndFunc


Func _B64Encode($binaryData, $iLinebreak = 64)
	If Not $binaryData Then Return SetError(1, __WinHttpErrorNotify('_B64Encode', 1), '')
	Local $lenData = StringLen($binaryData) - 2, $iOdd = Mod($lenData, 3), $spDec = '', $base64Data = ''
	For $i = 3 To $lenData - $iOdd Step 3
		$spDec = Dec(StringMid($binaryData, $i, 3))
		$base64Data &= $g___aChr64[$spDec / 64] & $g___aChr64[Mod($spDec, 64)]
	Next
	If $iOdd Then
		$spDec = BitShift(Dec(StringMid($binaryData, $i, 3)), -8 / $iOdd)
		$base64Data &= $g___aChr64[$spDec / 64] & ($iOdd = 2 ? $g___aChr64[Mod($spDec, 64)] & $g___sPadding & $g___sPadding : $g___sPadding)
	EndIf
	If $iLinebreak Then $base64Data = StringRegExpReplace($base64Data, '(.{' & $iLinebreak & '})', '${1}' & @LF)
	Return $base64Data
EndFunc


Func _B64Decode($base64Data)
	If Not $base64Data Then Return SetError(1, __WinHttpErrorNotify('_B64Decode', 1), '')
	$base64Data = StringStripWS($base64Data, 8)
	If Mod(StringLen($base64Data), 2) Then SetError(2, __WinHttpErrorNotify('_B64Decode', 2), '')
	Local $aData = StringSplit($base64Data, ''), $binaryData = '0x', $iOdd = 0 * StringReplace($base64Data, $g___sPadding, '', 0, 1) + @extended
	For $i = 1 To $aData[0] - $iOdd * 2 Step 2
		$binaryData &= Hex((StringInStr($g___sChr64, $aData[$i], 1, 1) - 1) * 64 + StringInStr($g___sChr64, $aData[$i + 1], 1, 1) - 1, 3)
	Next
	If $iOdd Then $binaryData &= Hex(BitShift((StringInStr($g___sChr64, $aData[$i], 1, 1) - 1) * 64 + ($iOdd - 1) * (StringInStr($g___sChr64, $aData[$i + 1], 1, 1) - 1), 8 / $iOdd), $iOdd)
	Return $binaryData
EndFunc


Func _B64SetupDatabase($___sChr64, $___sPadding = '=')
	If StringInStr($___sChr64, $___sPadding, 1, 1) Then Return SetError(1, __WinHttpErrorNotify('_B64SetupDatabase', 1), False)
	Local $___aChr64 = StringSplit($___sChr64, "", 2)
	Local $___iCounter = 0, $___uBound = UBound($___aChr64) - 1
	If $___uBound <> 63 Then Return SetError(2, __WinHttpErrorNotify('_B64SetupDatabase', 2), False)
	For $i = 0 To $___uBound
		For $k = 0 To $___uBound
			If $___aChr64[$i] == $___aChr64[$k] Then $___iCounter += 1
		Next
		If $___iCounter = 2 Then Return SetError(3, __WinHttpErrorNotify('_B64SetupDatabase', 3), False)
		$___iCounter = 0
	Next
	$g___sChr64 = $___sChr64
	$g___aChr64 = $___aChr64
	$g___sPadding = $___sPadding
	Return True
EndFunc











#Region <INTERNAL FUNCTIONS>
	Func _WinHttpReadData_Ex($hRequest, $ptCallBackFunc_ReadWrite = '', $iNumberOfBytesToRead = 8192)
		$g___MaskFunc = 1
		$g___PosLoop = 0
		$g___NumberOfBytesPerRequest = $iNumberOfBytesToRead
		;----------------------------------
		Local $vBinaryData = Binary(''), $aCall, $tBuffer, $iCheckCallbackFunc = 0
		Local $vType = (BitAND(_WinHttpQueryOption(_WinHttpQueryOption(_WinHttpQueryOption($hRequest, 21), 21), 45), 268435456) ? "ptr" : "dword*")
		If IsFunc($ptCallBackFunc_ReadWrite) Then $iCheckCallbackFunc = 1
		While 1
			If $g___CancelReadWrite Then Return SetError(999)
			$g___PosLoop += 1
			$tBuffer = DllStructCreate("byte[" & $iNumberOfBytesToRead & "]")
			$aCall = DllCall($hWINHTTPDLL__WINHTTP, "bool", "WinHttpReadData", "handle", $hRequest, "struct*", $tBuffer, "dword", $iNumberOfBytesToRead, $vType, 0)
			If @error Or Not $aCall[0] Or Not $aCall[4] Then ExitLoop
			If $aCall[4] < $iNumberOfBytesToRead Then
				$vBinaryData &= BinaryMid(DllStructGetData($tBuffer, 1), 1, $aCall[4])
			Else
				$vBinaryData &= DllStructGetData($tBuffer, 1)
			EndIf
			If $iCheckCallbackFunc Then $ptCallBackFunc_ReadWrite()
		WEnd
		Return $vBinaryData
	EndFunc

	Func _WinHttpWriteData_Ex($hRequest, $sDataToSend, $ptCallBackFunc_ReadWrite = '', $iNumberOfBytesToWrite = 8192)
		$g___MaskFunc = 2
		$g___PosLoop = 0
		$g___NumberOfBytesPerRequest = $iNumberOfBytesToWrite
		;----------------------------------
		Local $aCall, $iLenOfBytesToWrite, $tBuffer, $iBytesToWrite, $iStart = 1, $iCheckCallbackFunc = 0
		If IsFunc($ptCallBackFunc_ReadWrite) Then $iCheckCallbackFunc = 1
		$sDataToSend = StringToBinary($sDataToSend)
		$g___DataSizeBytes = BinaryLen($sDataToSend)
		If $g___DataSizeBytes > 2000000000 Then Return SetError(-1, '', False)
		$g___TotalLoops = Ceiling($g___DataSizeBytes / $iNumberOfBytesToWrite)
		For $i = 1 To $g___TotalLoops
			$g___PosLoop += 1
			If $g___CancelReadWrite Then Return SetError(999)
			$iBytesToWrite = BinaryMid($sDataToSend, $iStart, $iNumberOfBytesToWrite)
			$iLenOfBytesToWrite = BinaryLen($iBytesToWrite)
			If $iLenOfBytesToWrite = 0 Then ExitLoop
			$tBuffer = DllStructCreate("byte[" & $iLenOfBytesToWrite & "]")
			DllStructSetData($tBuffer, 1, $iBytesToWrite)
			$aCall = DllCall($hWINHTTPDLL__WINHTTP, "bool", "WinHttpWriteData", "handle", $hRequest, "struct*", $tBuffer, "dword", $iLenOfBytesToWrite, "dword*", 0)
			If @error Or Not $aCall[0] Then Return SetError(-2, IsArray($aCall) ? $aCall[4] : '', False)
			$iStart += $iNumberOfBytesToWrite
			If $iCheckCallbackFunc Then $ptCallBackFunc_ReadWrite()
		Next
	EndFunc

	Func __WinHttpCancelReadWrite()
		$g___CancelReadWrite = True
	EndFunc

	Func _HttpRequest_ClearCookies()
		_HttpRequest_NewSession()
	EndFunc

	Func __WinHttpCloseHandle()
		_HttpRequest_NewSession()
		If $hWINHTTPDLL__WINHTTP Then DllClose($hWINHTTPDLL__WINHTTP)
		If $g___User32DLL Then DllClose($g___User32DLL)
	EndFunc

	Func __WinHttpErrorNotify($__TrueValue = '', $__ErrorNote = 0, $__FalseValue = '')
		If $g___ErrorNotify = True And $__ErrorNote Then
			ConsoleWrite('! ' & $__TrueValue & ' Error: ' & $__ErrorNote & @CRLF)
		Else
			Return $__FalseValue
		EndIf
	EndFunc
#EndRegion






#Region -------------------ZLIB UDF by [WARD] autoitscript.com--------------------------------
	Func __MemVrAlloc($pAddress, $iSize, $iAllocation, $iProtect)
		Local $aResult = DllCall("kernel32.dll", "ptr", "VirtualAlloc", "ptr", $pAddress, "ulong_ptr", $iSize, "dword", $iAllocation, "dword", $iProtect)
		If @error Then Return SetError(@error, @extended, 0)
		Return $aResult[0]
	EndFunc

	Func __MemVrFree($pAddress, $iSize, $iFreeType)
		Local $aResult = DllCall("kernel32.dll", "bool", "VirtualFree", "ptr", $pAddress, "ulong_ptr", $iSize, "dword", $iFreeType)
		If @error Then Return SetError(@error, @extended, False)
		Return $aResult[0]
	EndFunc

	Func __ZL_Alloc($Opaque, $Items, $Size)
		Local $aResult = DllCall("kernel32.dll", "handle", "GlobalAlloc", "uint", 0x40, "ulong_ptr", $Items * $Size)
		If @error Then Return SetError(@error, @extended, 0)
		Return $aResult[0]
	EndFunc

	Func __ZL_Free($Opaque, $Addr)
		Local $aResult = DllCall("kernel32.dll", "ptr", "GlobalFree", "handle", $Addr)
		If @error Then Return SetError(@error, @extended, False)
	EndFunc

	Func __ZL_Exit()
		$Z_Buffer = 0
		__MemVrFree($Z_BufferMemory, 0, 0x8000)
		DllCallbackFree($Z_Alloc_Callback)
		DllCallbackFree($Z_Free_Callback)
	EndFunc

	Func __ZL_Startup()
		If IsDllStruct($Z_Buffer) Then Return
		If @AutoItX64 Then
			Local $Code = "1K0AAP8OAejNKRwOTI0DQblYcBAY6Q95Cv8CMOi4K0iD7OZFdosFBMdEJDgfHFiJEjBBGYtADBEoEggmIELg6Ph1oS3EzMP/DAPpsWyBBO/9V58PBYi9VYUh6GoBTonCQbhRYwOOECLoVYhJiVPAeBEIjTsjmWqPDyT4OqWJYfifKIBWV8x0zwbWdkwBwfzzpF9ew0gQ0IY/ql+5WA3o+f8CwiCWMAd3ACxhDu66UQmZHxnEbUCP9GpwNaUAY+mjlWSeMogB2w6kuNx5HvjV4PbZANKXK0y2Cb18ALF+By2455EdB7+QZBC3YPIgsGoASHG5895BvoQAfdTaGuvk3W08UbWA9MeF04NWmABsE8Coa2R6+QBi/ezJZYpPXAMBFNlsBmOIPQ/6KPUNvgDIIG47XhBpTADkQWDVcnFnonnRAAM8R9QES/2FAA3Sa7UKpfqo6jUAbJiyQtbJu9sHQPm8rOPQ2DJ1XADfRc8N1txZPQHRq6ww2SY6wN5RcoAA18gWYdC/tfQAtCEjxLNWmZUBus8Ppb24nsgCKAAIiAVfstkMxpAgAAuxh3xvLxFMAGhYqx1hwT0tAGa2kEHcdgZxANsBvCDSmCoQB9XviYWx4B+1tgYApeS/nzPUuOgDoskHeDT5gA+OqAAJlhiYDuG7DQBqfy09bQiXbABkkQFcY+b0UXFrPmJhgRzYMGWFTsPQ8u2VfQYAe6UBG8H0CIIAV8QP9cbZsGUAUOm3Euq4vosAfIi5/N8d3WIHSS3aFfPQ04xlTAHU+1hhsk3OIC06cHQAvKPiMLvUQaUG30rXldjEAMTRpPv01tNqAOlpQ/zZbjRGAIhnrdC4YNpzAC0EROUdAzNfAEwKqsl8Dd08HnEFUENBAicQiAu+hgAgDMkltWhXsz2FbwAJ1Ga5n+RhAM4O+d5emMnZOikigNCwtKjXxxcHPbNZgQ2gLjtcvQC3rWy6wCCDuAHttrO/mgzi2QPU0rEBdDlH1eqvd+SdFQAm2wSDFtxzEgALY+OEO2SUPgdqbQ2oWld68M8O5J0H/wmTJ64ACrGeBz19RAAP8NKjCIdoAPIBHv7CBmldAFdi98tnZYBxDzZsGefga252G9QA/uAr04laetoAEMxK3Wdv37lx+Q7vvo5DY7cX1bCwYOg4o9aAfpPRocTC2AA4UvLfT/Fnu/vMV7wApt0GtT9LNrIASNorDdhMGwoPr/ZKA8BgegRBw3bvOd9VHWeowI5uMXm+aQBGjLNhyxqDZgC8oNJvJTbiaABSlXcMzANHCwC7uRYCIi8mBQNVvju6xSj4vbKSAFq0KwRqs1ynAP/XwjHP0LWLAJ7ZLB2u3luw/GQAmybyY+yco2oAdQqTbQKpBgn2PwA2DuuFZwdyE7CNAAWCSr+VFHq4AOKuK7F7OBu2AAybjtKSDb7VAOW379x8Id/bPwvUh9OGQuJg8fiz3QBoboPaH80WvgCBWya59uF3sHNvBEe3GOZawH5wag8A/8o7BmZcCwF5EQCeZY9prmL40/JrTGHFAGwWeOIKoO4A0g3XVIMETsIAswM5YSZnp/cAFmDQTUdpSdsAd24+SmrRrtwAWtbZZgvfQPAPO9g3U8C8qcWeuwDef8+yR+n/tQ4wHPK9IYrCusrkk7MAU6ajtCQFNtD77AbXuJ0AV95Uv2fZIy4AemazuEphxAIAG2hdlCtvKjcBvgu0oY4Mw/zfBQVaje8CLcgAQX4xARmCYjYyw1P+QSTFMNlFAPR3fYanWlbHAJZBTwiK2chJHbvC0cPo7/rL2PTjDANPtaxNfq6oji2DAJ7PHJiHURLCAEoQI9lT03D0AHiSQe9hVdeuBy4U5rU3fmCYHJaEgzsFWYcbghipAJvb+i0PsJrLNk5dIXfmHGzE/98A"
			$Code &= "P0HUng5azaIAJISV4xWfjCAARrKnYXepvqYD4ejx59DzqCSD3gHDZbLF2qqugGTrn0ZEKMwDa29p/XB2/3AxOe9aACogLAkHC204ARwS8zZG37LsXcYLcVRw7QCDa/T38xIqu7YA4qJ1kRyJADSgB5D7vJ8XALqNhA553qklBzjvsjz/kPNzvkgD6Gp9G8VB6CreWAAFT3nwRH5i6TyHLYXCxhxUwAmKFZQAQLsOjYPoI6YBwtk4vw3FoNRM9AG7IY+nlgrOzI0TcAkAzFxIMddFi2IJ+m7KUwDmVF27uhMVbKAAxj+NiJcOAJaRUJjX3hGpAMzH0vrh7JPLuON/XABich3meWvetQBUQJ+ET1lYEgAOFhkjFQ/acA84JJtBID2na/1lmCTkfAAlCctXZDjQTi6jrlcA4p+KGCHMAKczYP28Kq/hAiSt7tA/tEBvEp8HbLIJhqvwSMnqFQBT0ClGfvtodwBl4vZ5Py+3SAAkNnQbCR01KgASBPK8U0uzjQBIUnDeZXkx7wB+YP7z5ue/wnf9AHyR0NU9oMvMA/o2ioO7B+iaeFQAvLE5ZaeoS5j+OzoKqYAiyfq1CYjLAK4QT13vXw5sAfRGzT/ZbYzkwnQAQxJa8wIjQeocwXBs3YDAd9hH1zaXAwbmLY7FtYGlhMQbvAAaikFxW7taaAeY6HdD2RdskB5PLRUHX342DJxwGyfdHOA+cBIAmLlTMYOgkGIerovRQLWSFsX03XNXB+/ElKfCUNWW2fYA6bwHrqiNHLeQIQ4xnCrvRIXtgCvKrEgBcNNvG134LvxG4eI2JN5mxwHFf2NU6MgiZRzzTeXAsgKkwqkbAGeRhDAmoJ8pB7iuxeT5cN79Oswd89Z7gOjPvGupgPpaB7KZPgmfUH84hKsAsCQcLPEVBzUBMkYqHnN3MeS04QBwSPXQa1E2gz9GeoKyXWNO12DXD+YO4dLMtUn5jyeg4EoSlq89CyMAtshwoJ2JQQ+7hEZdoAMHbDgaA8Q/FTGFDogoQpgAT2cDqVR+wPoAeVWBy2JMH8V3OABe9COYnacOswfclhWqGwBU5VoxDk/8mWIg19hTec57FwDhSVZ++lCVLf57AdQczGITio3oUrsOljSR6KAf0NmgBgDs835ercJlRwdukUhsL/BTdeg2ABI6qQcJI2pUACQIK2U/EeR5mHkApUi8j2YbkaQHJyqKveCwy/KhjRTQ62LzAMAj7+bZveEfvBT8wKcNP4OKJh1+spHPuSSgcPgVy2kKO0bmQuEA/Vu1a2XcAPRafsU3CVPuA3Y4SPexrsi48J8AEqEzzD+Kcv0uJJMAQDdqwgEAbtSEA1m+RgIs3KhZH+vAywayfI0EAIUWTwW4URMOB4870Q/W0JcN4e8GVQxk+RqUA5PYCAotnpk9R3DScB2jJhzAyeQdHneiOx8pO2CArAsvG5th7QAawt+rGPW1aQAZyPI1Ev+Y9wATpiaxEZFMcwAQFFo8FSMw/u56B464Fk3kYRfgRtg41x8sjznAksk7ufgLBzo87kQ/YISGPlL0wPZlAFACPVgXXjZvHX2cN0DD2jUBqRgANIS/VzGz1ZUAMOpr0zLdAREeM5DlRSSnj4Lc/mDtJ8kAWy0mTE1iI3v0oHEiAJnmIBXzJCEoALR4Kh/euitGA2D8KXEKPvn0HNgtwwB2syyayPUurQeiNy/AjaBw9+dYE3GuWQAfmTPcchwBJZN3K09RduTxFwB0RZvVdXjciX9+ALZLfxYIDX0hAGLPfKR0gHmTAB5CeMqgBHr96sYCe7AuvGyH4EFt3gX6OG/pkMcU1IaAclvsdwBqAlIxaDU48wRpCH+vYsA7bWNmAKsrYVHB6WDUA9emZeO9ZIi6AyIAZo1p4Gcgy9cBSBehFUlO"
			$Code &= "H2C4ebi1AEr8Y95Pywkc/pIBt1pMpd2YTciaxABGr/AGR/ZOQAdFwSSCRBAyzUFzPlgPgCrmSUIdjIsAQ1Bo8VRnAjMAVT68dVcJ1rcAVozA+FO7qjoAUuIUfFDVfr4eUeg5gFrfUyBbhgHtZlmxh6RYMHnrAF0D+ylcWkVvAF5tL61fgBs1AOG3cffg7s+xAOLZpXPjXLM8POZrgP7nMme45QUADXrkOEom7w93IADuVp6i7GH0YHrtB+Iv6NOIcOmKNqsA671caerwuBNc/e0A0fyebJf+qQAGVf8sEBr6GwB62PtCxJ75dQeuXPhI6QDzf4PCAPImPYTwEVdGAPGUQQn0oyvLAPX6lY33zf9PAPZgXXjZVze6ANgOifzaOeM+ANu89XHei5+zHt/SIUDd5Us33NgADGvX72ap1rbz2NSBALIt1QSkYtAzAM6g0Wpw5tNdABok0hD+XsUnAJScxH4q2sZJAEAYx8xWV8L7ATyVw6KC08HY6BEAwKivTcufxY+Sqh/JyPHdC0B0B0TMQ20Ahs0a08DPLbkWAs5AAO+Rd/xtkAAuQiuSGSjpkwCcPqaWq1RklwDy6iKVxYDglAD4x7yfz61+ngCWEzicoXn6nQ8kb7WYYAV3mUq7ADGbfdHzmjA1AImNB19LjF7hAA2OaYvPj+ydB4CK2/dCoIJJBIkOtSPGiCBkmoO/Dn9YAOawHoDR2tyBAFTMk4RjplGFADoYF4cNctWGAKDQ4qmXuiCoAM4EZqr5bqSrAHx4665LEimv5qwOb60lxn2AGIHxpy/rADOmdlV1pEE/ALelxCn4oPNDADqhqv18o52XAL6i0HPEtecZPQa0AKdAtonNgrc6DNuBsjuxD7NizUnYVWUAi7BoIte7X0gAFboG9lO4MZwAkbm0it68g+AAHL3aXlq/7TQumL4AQGVnvLgAi8gJqu6vtRIBV5dijzLw3iB5XxZrJbkFmp3vgEHFik8ACH1k4L1vAYfk1wC4v9ZK3dhq8gAzd9/gVhBjWACfVxlQ+jCl6HkU+9xx+ACsQsjAe9+tpwDHZ0MIcnUmbw/OzXB/wJUVGBEtA/u3pD+e0MiHJ+gAzxpCj3OirCAAxrDJR3oIPq8AMqBbyI4YtWccOwrQAIeyaThQLwAMX+yX4vBZhf3Y5T110QCGZbTgOt1aTw2Pzz8o7PgQ5Dvq4wBYUg3Y7UBoDr9R+KFAK/DEn5cMSCowIkZXAJ7i9m9Jf5MIEvXHfQIQ1RjAQNlO0AGfNSu3I43F9ZbkoH8AKicZR/26fCAAQQKSj/QQ9+guSKhhDhSbbj/gI7aQHTEA0/ehiWrPdhR/DwDKrOEHf76EYADDBtJwoF63FwAc5lm4qfQ83wAVTIXnwtHggAB+aQ4vy3trSEx3aB4PDUHHaLFzKdQEYQBMoLjZ9ZhvRACQ/9P8flBm7gAbN9pWTSe5DgAoQAW2xu+wpAejiAwcGnDbgX/XAGc5kXjSK/QfAG6TA/cmO2aQmCQDiD8vke1Y+ClUYABEtDEH+AzfqAFNHrrP8abs5JL+AIm4LkZnF5tUHwJwJ8W7SPCAIS9MyQAwgPnbVedFYw+coD9rQMeD0xdoADbBcg+Kecs3AF3krlDhXED/AFROJZjo9nOIf4scFu83wPhAggSdJ7gmACQf6SFBeFWZAK/X4IvKsFwzADu2We1e0eVV90CxR9UZAOz/bCE7YglGAIfa5+kyyIKO4nAA1J7tKLH5UZAfX1bkxzoxWDCDCY+nAOZuMx8IwYYNP22mg7Wk4UC9ABb8BS8pSRdKAE71r/N2IjKWABGeini+K5gdA9mXIEvJ9NgurkhxwAAB/dKlZkFqHABelvd5OSpPl5CPC13y8SOAZBlrTWAAftf1jtFi5+sPtt5fUiAJ"
			$Code &= "wjfptRx62UYHaLwhINDqMd8AiI9WYzBh+dYBIgSeapq9psgH2ADBAb82brStUwAJCBWaTnId/wApzqURhnu3dADhxw/N2RCSqAC+rCpGERk4IwB2pYB1ZsbYEAABemD+rs9ymwDJc8oi8aRXRwCWGO+pOa39zABeEUUG7k12YwCJ8c6NJkTc6ABB+GRReS/5ND0ekwTasSZTwOua6+l/xgCzjKFFC2IO8A8ZB2lMQL5RmzzbADYnhDWZkpZQOP4u9wC5VCb83uieEgBxXYx3FuE0zgMuNqmrSYoAsuY/AyCBg7sAdpHg4xP2XFsA/VnpSZg+VfEDIQaCbERhyNSqzgCLxs+pN344QQB/1l0mw26ziTx2fIfuysRv4B1ZCrEAoeHkHhTzgXkAqEvXacsTsg4Ad6tcocK5OcYAfgGA/qmc5ZkEFSQLNqCAA1EcjgCnFmaGwnHaPhws3m/ASbnTlPCBAQQJlea4sXv0DaM7Hi6AG0g+0kMtWQBu+8P22+mmkQBnUR+psMx6zgAMdJRhuWbxBi4F3gBAdwcwlgDuDmEsmQlRuvZtAMQZcGr0j+ljAKU1nmSVow7bAIgyedy4pODVB+kel9LZ0Am2TCsAfrF8vee4LQcOkL8dkUC3EGRqsAAg8vO5cUiEvgBB3hra1H1t3R3k6/TJtVGAloXHE2wAmFZka6jA/WIA+XqKZcnsFAEAXE9jBmzZ+g93PQCNCA31O24gyABMaRBe1WBB5AOiZ3FyPAO40UsEANRH0g2F/aUKHLVrNcCo+kKymGwA27vJ1qy8+UA9MtiB40XfXHXc+A3PAKvRPVkm2TCsUFHGOjvI1wCAv9BhFiG0APS1VrPEI8+6AJWZuL2lDygC7J4AXwWICMYM2bIAsQvpJC9vfIcAWGhMEcFhHasAtmYtPXbcQZAAAdtxBpjSILwP79UQKkOxhYnotrUfF5+/5ADVuNQzeAdYyeNwmBMAlgmojuEOmBgAf2oNuwhtPS0AkWRsl+ZjXAFxax5R9BzAYWKFZTDYdvLgTvYGAJXtGwGle4IIAPTB9Q/EV2WwANnGErfpUIu+ALjq/LmIfGLdXB1GA9otSYzT2PP71AVMZU2yYYVVAyvOo7yDdPi7MOIASt+lQT3YldcApNHEbdPW9PsAQ2npajRu2fwArWeIRtpguNAARAQtczMDHeUAqgpMX90NfMkBUAVxPCcCQfy+C3EQ+gwDIIZXaLUlsG+Fs5DeANQJzmHkn17eAPkOKdnJmLDQ5iIAx9eotFmzPRd2LgANgbe9XDvAugBsre24gyCavxyztgOT4gcVsdKw6tVHOXedAHevBNsmFXPcABaD42MLEpRkLDuE7QdqPnowWqjkDgHPC5MJ/50KwK4nA30HnrHwD/BEhwgAo9IeAfJoaQYAwv73YlddgGUAZ8sZbDZxbmsABuf+1Bt2idMAK+AQ2npaZ90ASsz5ud9vjr537zoXt49DYLBH1dYQo+ih0ViTCADYwsRP3/JS9rtcZ/UdvFdAP7UG3UiyADZL2A0r2q8KPRtMAgNK9kEEwcjfyO/DO6hnB1Uxbo6RRmm+cPBhsJ8AvGaDGiVv0qAAUmjiNswMd5UAuwtHAyICFrkAVQUmL8W6O74Asr0LKCu0WpIAXLNqBMLX/6cAtdDPMSzZnosAW96uHZtkwrAA7GPyJnVqo5wOAm2TCqAJBqnrDgE2P3IHZ4UFwFcTAJW/SoLiuHoUAHuxK64Mths4AZLSjpvl1b4getwA77cL298hhtMc0tTxgOJCaN2z+AAf2oNugb4WzQD2uSZbb7B34R0Yt0dmegBa5v8PanAAZgY7yhEBC1wfj2WewPhirmlha+7TABZsz0WgCuJ4ANcN0u5OBINUADkDs8KnZyZhANBgFvdJaUdN"
			$Code &= "AD5ud9uu0WpKANnWWtxA3wtmADfYO/CpvK5TAN67nsVHss9/BzC1/+m9EPIcyroHwopTs5PwJLSjpvbQBzYFzdcG0FTeVykSI9lnANpmei7EYQBKuF1oGwIqbwArlLQLvjfDDACOoVoF3xstAi7vjQBHGaAxQTI2AmKCKy1Tw2DXxQQAfXf0RVZap4YAT0GWx8jZiggB0cK7Sfrv6OTj9PrLDqy1Twxgrn5NnoMALY6HmBzPSsIAElFT2SMQePQAcNNh70GSLq4A11U3teYUHJjr5AWDD4SWghsnWZsAqRiwLTv62wE2y5rmd13E/2ziHADUQT/fzVoOngCVhCSijJ8V4wCnskYgvql3YQ7x6OGmYPPQ58PeA4Mk2sWyZQBcrqpERp/rbwBrzCh2cP1pOXkxAK4gKlrvCwcJACwSHDht30Y2H/PGXUCy7XBUcfRYa4UfuyrA96IxwraJAByRdZAHoDQXAJ+8+w6EjbolAKneeTyy7zhzd/ML/2roSICqxRt9WA/eKjzw4E8F6WJ+O0TCgC2H21QcxpQAFYoBjQ67QKYBI+iDvzjZwsygxT8NIYD0TAqWp48TdY0czlzMAAlF1zFIbhL6YosJ4lMAe7tdVKMAoGwViI0/1pEAlg6X3teYUMcAzKkR7OH60vXmywCTcmLXXGt55gAdQFS13llPhACfFg4SWA8VIwMZJDhw2j24QZtlCf1rp3x4AQBXywklTtA4ZAABka6jGIqf4gAzp8whKrz9YACtJOGvtD/Q7iSfEnEAhgmybMlIPySrAFMV6vt+RikA4mV3aC8/efYANiRItx0JG3QBBBIqNUtTvGFF/I2zAHll3nBgfu8xDufm8/4g/cK/1dAAkXzMy6A9g4oeNvqawAe7sbxUeACop2U5O4OYS3MiAKkKCbX6yRCuAMuIX+9dT0b0AGwObdk/zXTC7owA81oSQ+pBIwIcwWxwz9h3IICXNtdHB44t5galALXFvBtxhABxQYoaaFq7Ww5Dd+iY52zZEBUtTx4EDDZ+XyfBXpw+wBzdOLmYABKggzFTi64OYpCSteDR3fTFFjrE77lXzOoAlPbZltWuBwC86bccjaicMRLea4XwAcqQLQDt03BIrPhdGx9v4UbDLmbeNrl/xSHJKwH/Y03zZWDXsurlABupwqQwhJFnACmfoCbkxa64PP3egPnW88w6z+j0ewGAqWu8mbJa55ifCT4Aq4Q4fywcJLAANQcV8R4qRjLuMQB3c0hw4bRRax/Q9XrAgzZjXbJ3AMv6107S4eYPS/nDAeDcwCmvlhI7SrYBIwudoHDI+LtBPYkDg11GGjhsA3YVP8QoDoiFZ08AmEJ+VKkDVXkD+sBMYsuBiDjFHwCYI/Resw6nnQOqFZbc5VSAG/xPDjFa12Igmc55U9g+SeGAF1D6flZ71wktlWLMjvfAjYoTNJYcu1IfwOiRBqDZ0ABefvPsR2XCrT9sSIBudVOgLzoSADboIwkHqQgkAlRqET9lK2B3eeQAj7xIpaSRG2YDvYoqJ/LL6ODr0BSNocD1AWLZ5u8jFPzhvQANp9D8JoqDP+KRHrJ+cMAkuWnLFfgAQuZGO1v9d3oS3GVrAKl+WvTuUwEJN/dIOHa43K6xAKESn/CKP8wzC5Mk/XKQAAHCAGo3A4TUbgJGLL5ZVwCo3AbLwusABI18sgVPFoUADhNRuA/RO489DZeA1gxV7+EJGgD5ZAjYk1MKnnMtuM4ARz0cJqNwHeR5yQ4fonceL2BAKRsvC6wAGu1hmxir38IAGWm19RI18sgAE/eY/xGxJqYAEHNMkRU8WhTi/gEwIxa4jnoXyORNcjgARuA5jyzXO8kAko46C/i5P0QH7jw+hoSur8DAUj0CUGUANl4XWDecfW8eNdrDwDQY"
			$Code &= "qQExVwC/hDCV1bMy0w9r6jMR590kcuWQwNyPp0wn6wD+Ji1bySNiD01MIqDBeyDmmdwhJADzFSp4tCgrugPeHyn8YEbIPgpxci0AHPQss3bDLvUByJovN6KtcNiNwABxWOf3cx5ZrgBy3DOZd5MlHAF2UU8rdBfx/HXVAJtFfonceH9LALZPfQ0IFnzPAGIheYB0pHhCAB6TegSgynvG5v0FbLwusG3AP4dvOC763hQJkOkAboZsancA7FtoMVICafMAODVir38IY22YPQBhK6tmYOnBUQdlptfUZBO94+giA7oHZ+BpjUjwyyBJFSyhF7gFH05KxbOAjt5j/PIcAAnLTFq3kk2YB92lRsSaYEcG8K8ARUBO9kSCJMEdQc0y/YAPWHNCSeYqAEOLjB1U8WhQAFUzAmdXdbw+AFa31glT+MCMAFI6qrtQfBTiB1G+ftVaYDnoWyAAU99ZZu2GWKQAh7Fd65E0XCkA+wNeb0VaX60AL23hNRuA4PcAcbfisc/u43NMpVMDPLNc5/68gFa4ZzIA5HoNBe8mSjh57gAgD+yinlbtYAf0Yegv4ufpkIjT66sANorqaVy9/RMAuPD80dLH/pcAbJ7/VQap+hoBECz72Hob+fjEQgf4XK518wDpSPLCAIN/8IQ9JvFGAFcR9AlBlPXLACuj942V+vZPAP/N2XhdYNi6ADdX2vyJDts+AOM53nH1vN+zHZ+L3cAh0tw3S+UA12sM2NapZu9y1O62ANUtsoHQYqQEANGgzjPT5nBqANIkGl3FXv4QAMSclCfG2ip+AMcYQEnCV1bMAMOVPPvB04KiHsAR6IDLTa+oyo8JxZ/IyQ6uYAsR8cxEAAd0zYZtQ8/AAdMazgK5LZFg8UB/kAD8d5IrQi6T6T8oGQCmPpyXZFSrAZUi6vKU4ICAcrzH+J5+rQDPnDgTlp36eQShmLVvJMMlBeibMbsASprz0X2NiTUAMIxLXweODeEAXo/Pi2mKgJ127ABC99uJBEmCiAPGI7WDmmS/kFgOv4AAHrDmgdza0YQAk8xUhVGmY4cAFxg6htVyDakA4tCgqCC6l6oAZgTOq6Ru+a4A63h8rykSS606b6zy6sYAJafxgRimM+sAL6R1VXaltz8AQaD4KcShOkMA86N8/aqivpc/nbUAc9C0Bhnntj9ApwO3gs2JspjbDLMcD7E7nUlAYrCLZVW7ANciaLoVSF+4AFP2BrmRnDG8AN6KtL0c4IO/AVpe2r6YNO1yAAC4vGdlqgnIAIsSta/uj2KXAFc33vAyJWtfAtyd1zi5xcA/730BCE+Kb73gZP5eAQBK1r+48mo/2N0A33czWGMQVgBQGVef6KUw+uPvuBRCrAD4cd97wMhnxwCnrXVyCEPNzh5vJpWBf3AtERhgAaQdt/uHwNCeGs/oJwCic49CsMYgrAAIekfJoDKvPgAYjshbCjtntTiyhwDQL1A4aZfsAF8MhVnw4j3l9Ic5ZYaA0d064LTPjzBPWuQoP+oH5BCGUlig40Dt2AEN+FG/aPAr2KFIAJefxFoiMCriAJ5XT39Jb/bHCfUIk9UEEH2A18AYNQGf0E6NI7cr3ZbsxScAKn+guv1HGQIAQSB8EPSPkqgASOj3mxRYPSPyP+oxBx2Qtomh99Pwds9qrADKqA++fwfhBgDDYIReoHDS5gAcF7f0qbhZTAAV3zzRwueFaVh+MwB7yy8Ow3dId2soDQ/PB7Fox2EEMCnZuKAATERvmPX80/8AkO5mUH5W2jcAGw65J022BUAAKKSw78YcDIgeo4HbQBo5Z9d/KwDSeJGTbh/0OxMm9wMHJJBm0C8/iCkAk1jttERgVAwA+AcxHk2o36YH8c+6/pJw7EYuuAeJVJsXZ5AncAJxAPBIu8lML97b"
			$Code &= "APmAMGNF51VrAz+gnNODx/DBNmgAF3mKD3LkXTcAy1zhUK5OVP8HQPbomCWQi4hzFjk3758Egtf4ACInnSHpH5jAAFV4QYvg168zAVywyu1Ztjv85dEoXkev+v8P7BnVYsAhbNqHRpgOBzLp53COEIIo7Z4H1JBR+bGQ5FZfOpAm5qcAjwmDHzNu5g0PhsEItcCmbb1A4RikBfwaF0kLKS+v9YDDMiJ28wCKnhGWmCu+eA4gl9kdoPTJS8BIB64u0v0BcGpBZqUA95ZeHE8qOXlIXZEAl+Uj8fJNawAZBfXXfmDnYgDRjl/etuvCCe5SB3q16TdoAUbZ0C8BAYjfMepA6VaPIgDW+WGaap4EB5eAAb8BwdgCrbRuNhUI4O8dcgBOmqXOKf+3ewCGEQ/H4XSSEADZzSqsvqg4Gf5GAICldiPYxmZ1AGB6ARByz67+AMpzyZtXpPEiAO8Ylkf9rTmpAEURXsx2Te4GAM7xiWPcRCaNAGT4Qej5L3lR7JMfHjRTwrHa65pg7bP5AMbpC0WhjBnwOw5iAExpBzybUb4AhCc225aSmTVxLgf+UCZUuZCe6N78AIxdcRI04RZ3AKk2Ls4RikmrAAM/5kW7g4EgAOPgkXZbXPYTAEnpWf3xVT6YB2yCBiHUcGFExosAzqp+N6nP1n8AQThuwyZdfHYHibPEyu7zWR2Yb+GhALEK8xQe5EuoAHmBE8tp16t3AA6yucKhXAF+AMY5nKn+gCQVJZnlwP8LjgAcUW6GZhanPgPaccIsb96YlNO5AEkJBIHwsbjmHpWjDc97GyAuHkPSPgBI+25ZLenb9gDDUWeRpsywqQAfdAzOema5YQCU3gUG8ej233H/BcNIiVwkg8xBscpE5+NJ4NNQ6GzgLSrGAFhB99JFhcB0eCTOfAPPHsMPtgsYRNBJYzHB4uhnCB7R8IsUlkH6wgD/y3Xcg/sgDxKCKQK9szd8nEffcMHvBUU2MxNjFDfoEFh9FY5ehJYNBEcSPsiBEjOEjsPkMxgZGASGycK8KXBBDI58QwSGicFMV8BCeoVucL3qHkIIq3aFVkIQqzYUa4uFQiA6jEaFQkBJg8MgrEbKFuBJWfhKi6z8rT+RlOLABJQ8FISCFCE/SP/P+IXnTf1dJoskpDIEBHJUwHbZScEm6QIqorVlBAb8CaHQvjSHYnJAncl1E7OF23+tKOKAkPJNGN5gRV7DMcB5hQd0D/bCAVMCM6BIg8EGBNHqdfFu8uxYKA0s0hCyBsjg38pBN7kgvgZDiCgCTLMo6MjE5UGxwASg4cIMQPx1517EWChJzQgKMDEQe1cNgewgAWA1Uv3W0c9kRg8zjpmBuXApl+EbIC6WerDkTHqEkBUZwAHJfvjkfPH2jWxUNAqM6qDGTeh6ycgalGwQTMY06GgljSQRVkydQLoRrBINifroLCncx9EV+3QpPqIqmSwOVg9TRwMAdasx90yNnFIksQGJ+EmLWxCKCHMY5wHcX8PpKbpJqCR4oCV1A5ArxiTO+xuhHQh1MFAdRA+3kAIfweoQqMESAXU8D2YCvf98DIH58f+Wcm8HEo4PGFxFAWXKFPoWEwgioLIawowXbuKwGi4JyiJKPRAIbsPCjUIBrA2fEC5zRH1EEpLKA0vHQbFI5Mh1V+5gg7hxgN8pBc7iH4eOa9J+R40EEqDgEEQJUshKBYH4sBUKeg3egbivqW5eIKEcZCRc4AoLvzE8wFDjGoS5WzspaQWCECbCFjRD8d8yC/IcQ/OI9HH1DiH2xPc4+IcQ+eL6HEP7iPxx/Q4h/sT/Zg2QfphQ+/5FApXhCFQHaYKQYQHRkhaFD7vMbDLLYggpigEEJJVChBCS+aptIBzHJq9LI2TpBDHLAyrA8CMOv8lIEQ9AFI841Cbq"
			$Code &= "SJmpMtZI7lktb5psyzrrUxBJJuD9ooPoytd7E1hQBxqfAo2ECPBroUiip4spIySvy2jvxxJPmiYOk3gM20PKUhkRpKQk0WQXCMBIEMQHcT3i+QGcHAVcHhr+GC0aGAUYiMcImeymmJ9V4OpQxwvCKQoBlLcIyLbkq3KeOZMcf45HcitdOGgBwFNRUujhEFhILS7+KFWFx8OeDgcB+BTBCuEXd8LKBwE5FMt0CyE1sww2RND44vnAFthaWVvDN+iaO2G4ZQaHDUhj0fWtzM1ATBBxHuIDEikNa4svZWDUaW4DY29tcGF0wGJsZTkgdp5yc3+4bnw4dWbvFvsG/97cM0Rzdh94Y//kdCB1beWcJnkbZGKVMx9z138/lG0N205DjAtHGRxuZDn59dfPfIZ0zbthfzvYEDE5LjI4NU+jHZEBuAGtBJEC8gM+RwTIBfo8AYeH6G/yPF+MT1MGBCMHkQjICeQKcgs5DBwNjo+H6AF/IatFB2hXECgREpYABwkGCgULBAwCAw0CDgEPRwVFDEy7jAlMicwSLCSsSGyR7CIcRJxcidwSPCS8SHyR/CICRIJCicISIiSiSGKR4iISRJJSidISMiSySHKR8iIKRIpKicoSKiSqSGqR6iIaRJpaidoSOiS6SHqR+iIGRIZGicYSJiSmSGaR5iIWRJZWidYSNiS2SHaR9iIORI5Oic4SLiSuSG6R7iIeRJ5eid4SPiS+SH6R/iIBRIFBicESISShSGGR4SIRRJFRidESMSSxSHGR8SIJRIlJickSKSSpSGmR6SIZRJlZidkSOSS5SHmR+SIFRIVFicUSJSSlSGWR5SIVRJVVidUSNSS1SHWR9SINRI1Nic0SLSStSG2R7SIdRJ1did0SPSS9SH2R/SoTwugBzgiTEWQRU10iRdPSJDNdIkWz0iRzXSJF89IkC10iRYvSJEtdIkXL0iQrXSJFq9Ika10iRevSJBtdIkWb0iRbXSJF29IkO10iRbvSJHtdIkX70iQHXSJFh9IkR10iRcfSJCddIkWn0iRnXSJF59IkF10iRZfSJFddIkXX0iQ3XSJFt9Ikd10iRffSJA9dIkWP0iRPXSJFz9IkL10iRa/SJG9dIkXv0iQfXSJFn9IkX10iRd/SJD9dIkW/0iR/XSJF/9IrEThAkQkgImBEEFCJMBJwJAhISJEoImhEGFiJOBJ4JARIRJEkImREFFSJNBJ0JgOFZIMJQ0jDkSMio0Rj44rlBRwFExA3zY3H83yv2ZcIDBIcJAJIEpEKIhpEBhaJDhIeJAFIEZEJIhmBAhWRCQ0iHUQDE4kLEhskB04XHyUVjAMBAgMEiwWLBiIDB0cIIwmRCvILPkcM8g0/kQ7/Iw/+4cJYN+IT4hTIAxWRFsgX5Bh8GY+RGvwbj+Qcf8gd/6QH0kEFByL5UuVSu5RjohCZAREcEo5HEyMU5BV8Fo+RF/IYP5EZ/V+H8hx5msQB82KLBEcBJzn5Cj3diA6RECIURBgcyAkgkSgiMEQ4QIlQEmAkcEiAkaAiwFrge6hCh6IGmX8MTHcYpm9TMGcpYF+UwD3fK0FWCVvo2vbyr3gDKEb1CEtDwILYW8N/U1TjlXJWK6Qv5jHMAZrDHgl7ZbF6JPsYkIXC+S8wbSqn7RweKT3F4mg167YocfRLNS0THPgGw0iNgbwRUrqHAEUxwJBmRIngSJ0OS4H/ynXziDuwCU1FHhkRpAohE1G4uI8OTImBCRdav+4IyA9mCrwEDo30FuIvOZY+QZsYi4GcJP5NMWPQHNdK2+CRqAuAR40ADBJBOcEPj4nBm306SWPtTJA0gZkQhOGsEEIPtzAEhwsUn2YCOdByFXUWVl8GhAuklfI48AigCHcD9P9SwTrZY58LCEx1Elk4SAd28ZRa"
			$Code &= "wocF0UUByRCqM5GbkImEjneRS0KJWZ5855oKE8HUSsMLU2iFdyTqgwRVVlfonDAYHEIQTOga7HKfjyWYFGNQExgx27HH55tsCnONuYjZShGZCEgw3dqeFDyzEnjtBKzDuchkQRK9PQIgPkwkQBjzZqvGgKCrlTwOjFBoZkhBTh2LAnmomBWdh11jMEw56A8wjapxSSnFwZZkJFBN+aRQK0QB65J6Zkh0LAry78buHK1Kpkk2RBuCDDtMg0gwew050X4F1tfRwmZD7kx/MDv1f2SowcMYyQrS/4RAqUU7HrQKfAzEIo/qKR7PRYvYv4c8G50H5wmDr8e5AYAi+gJNhfZ0E4NbMwIp7sgYEQQJSYPE8KQJzQ+FdipQI5RI6UWioQryKQCqEQSF0g+EsxIBjY1K/70ywUGyhP2DvEgnCQO5kP/9UJMSIUCNdO8f9OoCxCQBrDY3gauKFiZAQ1CExqh/uUww20UQdFuQkqaI8JRApBkCdEVJjbyYRrQSY0f8Ca7voMjLOfB/SCqhS5JNREMXn+HQdBokFSkmwUNFlIvOIMhwiIhmRySJVH0k9jCKdcNBmv1gpnzEGF9eJl1b5FF8BmQEegKDy/+EQvm7LI2bHUQHSwWF8HUJuIrhBhuiD0H6QfaQ52ZFBYlEkwZITv+I8UvH7dRM+IBlssIKmdeKkzseiY59BIH6dGtF5crlC2B2ASyUkYRC6y+hxRU52tAIZpCjixIUEIHkGUwVH4P6zH8JH+iEZAcT7FGMQYsShAsaoWcD6xiyrh8GmJNI/f9CngeaC9QGqLFAyHWKTvmK1hjhIFahlXIxOxne3qjc4hTJzjXYbQ/+dbVdfCdOA2jXiC5BBZZmbHTziJcgoNxjAf3Qagam4Gf+lHUK4EcIRPeB/uQEYnYmyscRsDBFNpy5pqq3QOWJFEAXuLEUBUQp2IGWfmeEOYS5pDFRKCQjwA9m0+BJfJ0Q/h0JgXRZ1ORDCIgECn3OUigmZCYRUCdBF92RRFUTHjBtQo1EPRrwsdGC0+glkBU9Hx1rZzS/ZltSJAQZ9L9oSEAoIERV6VUBuevND8HEMEg2Mt8SpZfB/oy+isgiiZnmnaSUZnVpPxpTH6NbpFrENaKmiwGD+A5+Y02LMBT9pYd2ypDyhfDpO1wCPcPqA42vr68isnkOMkwcD4/SATHRmeryRSBk6Gq3+PZDDasj8+IbARbn9QInCiHucewarOyPYQl+YBz1hX5H94TrFIgHC4EHkC3iFQmRWUaCXQ16SvsIAwpQ6xa41sgdBkuEXgg2FfiDSsUIXcwI+PolpAog8kZ1nAaubIsoXtvDRIMZFMs2k0GJ5UTxx/jWgw/5C35bQY2S//6LhItTkUPCFnpQS+8JUoOVQdreuO3/Q2woRSERig0iKdmTRk00hegQ9cvqQdKTdjpioMa62qUaZinQsRpUA/gFicyKbUCAV6B5/8iTa6N89kTog4Z9ERSNQP917Awiflig4UP8r3bx9Auaqhx2RgQBRYXbD46ehGfo1OqQrY0ITRyJ2otTFGJQAUKHYX5dbw9/hDKW6euFl1RH88wVoJSqXGt7MrDiqJMRSWzic1bKoUhGP21BIAtGtwXGk+XSICzZFOhV+BMhRwiwCWkRWDBtsic4gK0gX+kzoiJCVNqazyyBuQ9J9cpo/T8UUhaI6JRFpRcB/4nBApPAePFPChdtiDnreUW85kiIMLzB6PNo8J7aNVakL4J4wICB+pUgSXIJwep7B1DCC1AU6MjuJAsMEFhCxygom0mDdIrwErsxwKjCPTnQaA98lC/DUxo/cDoXMDHtiSNDd8YqHtekBY1dEDmpRCiEh6ifWyVMtTsyLSc4pWJAgobtwdGCSdP56ebAawJGtuUMKP4n6Ij/xZCvGrYc"
			$Code &= "Ae+y3vSrFo2QdmPTiTHYRFOXAnDVyIljnxsEck5ScZ9kSiKCO8QsQolSCIKMRkojkjU8FnxIzwpyITrppAJ8m42XtRlWZc7k6YzCMeil70IqBba2xBODlYStiIeJYcJYdIcCQaMp8FKcXxd6BJsyfOtXEpjQlz0xaDYzKMQgauYFRosEoFj8to6IFBQR/u8QKxxICFREKVTAoluunUjDOarIAsTrSJpPO5ny40krAZAkCdGc2mRAQYH5mWoKcw6UCFzsE0JBbQhY6xcuhE2BoQcFRBuIq0FC7Gg0n4V0jgL8S0kM1F2iRySePrETQ0VfP14Qk+XImNEnDAxCmPeoXUTpSIpZ4RyKjQs7qht06aL8RY/zuDpsIBCab7FVpJKLnwIq90zr5NZESDCitHMlM0WPhEZFi/iAjlIQrsCFvE/0pmg2vSG5aC/tMQ++cUTTGmXwSstsvxbKqodlJlbxGV3FoTukshwMK+S1L1vDib1gubh/uIFO85kT9fbwAXQOBmaDOAB1UEj/wpeh40HR6IMO+h9+5CcsuWR8N3U5FehkL0jwZCW7I5xJEIw8AURAE4HBCd5smiV86lBal5MqthKAh8j/HcrR6cGD4AFECa7kXQx/7M7DT4skTVKWuA4TdT7YtEQSi0EoCU9RGgZwnpy7cUgdtC2m5opB+zivzMOGCCl8Li2QEPQ0PPIHKoMzV/g0Q4DCCH4fiHk96IBaGEDrDJinK34WXTTRbY0ZUh2VONPTiM5FnWTjuc8Ey+iMsL5BJMeDkidmYpWkq1OC9UskQ7hFNcvkxK2xIOP6U6ATZsHpCBGIDAKkkQX20V4UYXRm99FLLUvgjRnKUgcgRUtmpiyhn8cvwojnETA4GJO3FzvHUpGQp3tLQMAl6DPsny9kjVAZO2YeHURY6FJWGiNoCKQKZHAicTGAFVUQD5UOhul9N0lTDSdAQ2QMbEQkIlDLWEneWwJH2UG6ZCJMS7gTUEmgkEQ8A1ymIOEPAdtJRgFBVB5JMIcPBH7jTGPSgSh4KToSauGJUzIXPRJMBiCNQQHKYUQQ6J/9pbqDzASLE4LBTaDb16ncQC8pnisij3QJWpQcIEFUnVUWVslkOhmtCDJsx2O8YBSn4QiDzVK9z0GqkT5UDhFOlGrpklC11Z1kHUjRqwrkfjqgADkUjnQi/1CHJUhVYweZOMUGhO52fUGIlDk+RmbrBlILiVSOAioQeADATDnhfMYog78soZ2+SO59f1J7/eoGA//FienrA0O5UN/VjExOWDc2NIbIqThC/492c2DJdAxBiIECJymHamwYWHyuColqCItAgZkp0NH4MXEAqvB8FZiOUNjV8sIG+ehs1CeYyyrzffOUtJdviZ/6ZIDe8IsojJdyG41C/1v6j40WZ+6pTggKOQqPoDGhGyCngQ5N+cycSsqUnK3RIZo0HMG4+h2OZgMSniebmfiHQjtiEIw5EDjIwxTAcwMdCsH+6oLS3wr7hBqi9RRklgIGO55lCqdijfJAR8ToW6kRk+/DD4035SiXTKR2gv0PK6KJ6kJOjRboZOvXw8nyAdksiPEy+CVAL6eSksVQ+oZYWAeHQV4nXUNc6ZL9bKRcIAY7gczey5FmYZi2LRPtoj+BYJIWZA5w6NonGUb5YZJ1QbsSvVuYnd9VidqcciDDFoO8i9fMB3XLWDSBwcuAuPoDfeVDjRhMWxFG2AFwi5SXZCCklsq+8WwS07xlklzK871tZKSiNcwPHeG8YCUU81q5zcw/CZLRbDot6T/Cn8fBIZ5lu70lQLq/0rKadEKyKUuMRBA9LJarJNj4Ip+cMT9GRK/rly941qCN266OqiwebfB+RkzsRKVuZPciB5z6mCdB+S3Wmg5ZOQEpyIPACy4Sbg5z8hXsiFZNmjmP"
			$Code &= "+iT5mcnj6vxzDiQa45dOdproSszpXZ4Y6MSnPUZnQCXXXfKySs/bY0QPJVYGnWJPDhFe+D7HIgyVqc1HOa5d2kYogZ3PKN92vruW1VY2HmyYrGt+WgBMixFBg3pIAgZ1Ceh996M+iUJKgapACwzoLFX6SU/qWA9kRiYRIHL8WIsj3ZeTMejBCs3Cz3d48Ol7A3PqAznKdwjrBPiNUAWjrqtGz/fI8BtIhe0zdBZC+Z3IT+qhRKUQ6VEBy3u7UmQNBA+EsQ+ydhCpKVDYk72lamZUQBIEss//ddKps2XLA49EUJpwxGC3iLmlswzAwsJW3GHo9e4Fh7HJxG6VGN7pi6epRAI68gI2jJEKUOh835JImgnt2hClEFiRVglO8TCiqeSBhex0BfK4v4kKW3ERbFxcJkAlUXzt0Dl9J9gkjOAh6EH90CtOt/C4G/iLKbmg4AqxtAYTQQYomaQTEjn3fAHi6wL/y9TjEFoJDaG4Kad/+PY1kZwXrEB6Jw9NAZJUJMiOZFFQZqmULQ5NjSwqkuAB93PdGIPlA5hELSAGAQwx/ynFbpmgZQ9OBO9LjTQT8HIhvpQKXAuyjnlgeoh4uX47WjDCzpqCXCHQXD8MBEfI6O6GYnCDgepVLyKHiGTIISkKdHUleUsPIT/EUGwmh5AasHWR61MpJ87/EOPzhCnxheJY6vhH+XoeZtpbFyX5wEDLAki6+P7/UwFJ8LQ1CNixLLwNoAgPGDIUMgk6h+MEjo4znhZ1w6tE0wh1FvfX4hiEDBAnX5omYVQY2NjraHsRDDovqUijdRvvR1Z2DSVaBLDwIJgYfcBmBxAQIRkCLAEM0jWfg6xMKcg9/t12fbDqEth/ESVeKVQ/yLxBnoQ5lYGYyTw7SKs5fbJKQhDQwxVcCP8nxP3+SrtFISqdi6TjxMPC4k7+ckTYItBkXkLgJehJhPDXHBX4w14gz2VmJ2F0XxPoQZ+AQ29weXJpGWdodCA5x/gtMjDvy9BKZWF6bg9sb3VwT0cvaR5defMeZNtN2XJr5UHj/PoS2wLjU+hFceUewxYKyMtDeQgqsQsJZBgJKEE46F8PVxHIkVgyaAl4AoOIrjn0uIJbWMN3vLIjc10ZBAUIigkjXxDJds2UCBCyBlcOXFQQty1BigTiYhBNVPqoIBBxgMOUPCCKQjQyEAoOUZQEEKYcyCEQUtkW2ua/Zscc1gY8zUW8xM7BKoTzFQZ1WSgaQNvmhL8ktd1Ai0Msg/hkAhjRVq2DPwoJewgqhZ7CXA8BdAuLSUxwJ9CAiUXwg+wDFQ+CpTRIJwfHdgopRkG+5PgXSAHGTZxQ1mQW8hfow6sjQkP/PpXLSQwUo5QHiISsyh4QTFNwDEAEAdPiMcKwYSP8fFxBXzP9dsopMZA3Tz+TTLBGRDMQAiRw0SHSKB+LYOBUQTFhwEtoRCPRfLSmNqtHVEBmno1RPPKLGIcFDIlAjEU5GOF2slbrBT64/tzQuSWG+tksCVzDIxx0Fnoikhh5wAUNg3gsAoQdCcVQj2/KwzunqM4kGDRgeSjh3S1EK/NlJYknduFlkKLqSxikHP/J6EVeIUnoiEp5OkIGPypwKEkoCVghsDwkiYmRtBgTgaiLIgyk21we0rgoNWCNQj9EyQgHBV/Tg6sGtggCAwHQRY1UYm+ZzMYTTCijTQ1EuUGBLJS7fIJ0YmIJCEHcuULrb4OYUTAkGBLuwnRggsR6EAIIRIWuGK4KnBSUCEogRQ2sDkoXuoLghOEb85AtMLmQdDwwH20C6xnJ3IEQ0/fYe0X/jCTgBC0GPusDsDEbeUgPMnUmD3gFH+E6kAbZB9jB6g4y6RmHxAzzAcKSyonJcP8LGAfDQ4V2EMQaD+QGUvMie4JwrMFSCEWIDMJchiMWv6gUD1vD"
			$Code &= "y1JrKiX3UZPOztN6tMCHD0f4lro64iZSIFzFt4z7ERcw3PvoXTn7SJwlXmEbRrxcHlggx34cKTUYUg4nEsZ4EXxOkdkIdQimRbotIGVoi8NTe78pdL9V8icoZBq2JNJtMFeJ9IEUKnQxnQpFUCw9SSAnf1tAImf+HYFx/BiB/pq8aD6mEIjlfKNzIFv2UEgQlIoHs4RA/1PVmZafKEdoIUvkYC9xjzpFFQuxaaLvaDC4/eVMiVuQSXIPSdiGQnhGiEaDVCYYUlbkyNKRAULtPLrCInJA9q3TG+4RQvPBOOjjp0nKoN4lxDMgFxr0C9cqcRsBdRONR/xEf0mVXOY6KV7DJCVEu1vBiRh0jOhhnI+LV0SUGB9NZ0gCCki0JyYMMitHUNYyKXQWQmCCl/AWhX8EIhdoOzcOT2z2xSVTEMoo4R8cg39gMhbWMWgSyxKRycIRi0dHhUJWUMNvFZboB5V+pBHO00+ATQHA6PNUphR0iWgXSETfYhgkEF0N6M4jJVkgnI+kl/Qr9T8MYV8IAVTYiiDmyO0+EoUK9kWqlofysGTYS8ORwX4mlZuVveJAaRx5m4WP6BZIFVjJeZa/Qlj9lUBSYaT0wU9A/bi8IzsX69wt9B0fbdqkgsUI8dQQzzzAPsbYPy/wwfkSp7a+8Swp8EjNXyX4z+zA4PkBdanuF0LwTPCXGeg6ytsThCoCdRE4GIoP8noj2bof6QLz6LOlxIZyHyV3DBaI1jiaWkqdnajQVSZRdI+oYxv/yjGS+1ge92hmCzxQpA50D0mX4LUxSNKCjG6tTBZjm6yyaRhP+MeNCGRYMtu+QMLZAomDqJfmKXwEyBa0zS72BbhjDAbhu4QWDEScxyeDoHM2MhSIOyRYpJxiu5CCDXtwVDBY6U9L941SWlUQWUQmz95pC5quHsR3WNFIK7dAX42MA0n6lAEp1jnKcm0yoixJj4CNFBnomKSZW0kCwSmfenzIDJRkhExKRkCgq0L+wMDqAjnYcjoEKTzrShRlAlERQ3TmPGlgMdqODFiRSEEh6eo9NUYOrOds3koPuN9NCPIi44GZnAiHomKQngHC5gNIVz0Q3f17UYcbAouP0bIo1BQDci0om4JkRCyAV6B8BJWAs0dwQdMU4P/ADUsBjEQjR3xRFIH5eaMYcw1gB4NpeOMIU/GxchgXIwoFOfFzZTB4jRwB/Nn8KeLeW7hSKh+5U8ZQgYhRFCqUg4FAl6MDRDJIHqqfgzzrLuKDgCg5wXMkOSnLKs415sP+84HeCgjY6GKVATBNH8lctsmezclR5npQS1q+U+cfEEnA+6B4OfAPQucweYv8nLQNYncWxFwgEP6EE7E0EOWf5KFCAYNG6ooGyT8xNk0WdAVFWXJNvPBBxRcbajtByXgJlJrKtg5TUOuYEvpBLSnICABfCX3wkQabJm83C2qqXAroDLSsRAAbQTl7GHRSXnApRGsnjX17fBSaPAKRgk6s3b0IpV2hWpAj7LJC+NSoNBF7xfzz8qSsgzLl5ISb9yG9wmiI6Vif8P2XD2iKwY8UwG8QtO/oQ4cJdQ9Ex95tR0T4iSLriN5RQrkDsBTB6VVzj0+w0/XvSbRp1z7LpLy3Sqo8OL1qh53EPcyDJaSKSl4QChXiCFrJJNQCwcbnEaLc0MpTkKkuQ1261rQuU2AEjUkCyOoByy5wZoq0e2ks7CRMtneFSSHBt3p0tSYOSTGEQGZEaUg8zKVgOhT1mm9oEJoqBChB4LIi1VLBxCnRjcAg2HdSDrAQn/BeN4RVuxEGnSly2DjKsr5DRm6i8tI9ZuJW8acgplGTK7IeuEiTKSJD6CeA6uAQAeA6iBQU/4MXYlLCUf4+iArSQQQIWSuFCLzZS6bxAkU56HMOgh/kzxAMCFHru5QaBxIh"
			$Code &= "0ouMCPl/EmMU5vpBOimlZNLwVgqKOWG/U7pJCRLCKTJ0O1F+D3d4tjUQg0xvRlLdeOyUkXNfH1NkXtMkJFHuIGALdZ7pkz6Y18WZUzCeiLnHxEN9eE/F614plwSiWu48ikNaWfgW1Ek8a+UtZFEZk7zCFSkTIJpSnPrLRUpmWqqbV9JsvJpTFuhk7DpQFvP0PL8CQv2Wsw3XldysBkzDTL+qI/5C9esdOqH0Wf4LyP5dOjtWSiR30biJ1GLGIb8TviBgRI1vbwIGNmi1JqSVLJT4yvEJehS7RCy7y+ah+cuW+CLOcmnFyt7TfijJRN475mz79DdrG4UogqsN7fmgFILljCv8O4VaO4uIA3NYUvG0wvLBFGU9asIh26rsYvXA+AV3JzlPq9HYdBhRzXUaJqNN6Ys9XLiKdgdrbTSs1sDl1BFQQXw0h8gZNW0WLmQeFChXCVwB/bq+KcxQnsiojKTGrCrpwlDFQ8kc2LBJXPhAocrNDpILGfCwQKTLhUKSyzYuif4/W4qgxSxhiehAMIvGUSnIDL+NHkH+iVagLTlC2JMSwKzad0hO6JThmiiKr+UQSogMJcY2os6U5aHbI9x8TU8hx1vpGeJKCEG5OdGgCJjS0ctiE4X2NJTx/E7jSG0sYLnUmkCWcceyKHQhQfHiGv0UQlAhWBBghUFf7LzTCrY5eLXipd1jkYX/ycqQrHVcQHm+EOvn6Hpf8ElXAzIqzNcqOXjSIEj8lXnmIRrKNRGQGuksOTDPdEWvy/qyjs/S7n5X/GjTIqfJYrHv59OhMgtE/YJG6WfQ6C+4AxMCZCgm6MGT6VSnJ21mawnIxI2yuA1Q6KzKq+ggWFlEgJKrC4ECkbApSIfPQvNDGNOIkhqKXZEwLuZboJZBMtrJWcBIHhy7IEtMC8hBXN+FtlQCrCR/2QoXBOw5wpCAm+8/1AyQjKAVg8HpQhCAIE+NjArR6Bh2nQzPLnVSUguIR3E8DiExxCY4G4cQEOEFTNTJclyj4HUvjYES08aRtgMssqc00yRyfuDJzLil+JMsyr6Tj7pL9AogmgNci3GWCyPHk1InyPm3iatJJAWnCY7FDgnrXJx/m0jW0fBqmr1Z2elyaycD/hfY4ozkHQgb7Xm2C0+PuZLP2qIbl3GJquzN2keG+cXVJgZCdP8WnbqFRvmYAFo5IeN1FEFm6fD+mhBeWSy72rqStXfKXqzFc7qcUaJqiFiFevcolqoQHOPoq0PryTRRB+nxAkt8ExLqPmnEsuI6EEHr4h02j3EiENE7E08tXpNYwaIr1IBPj5ghqZF5IP9CnD6DpDCBlJELiDiRhh/HQWfGQcOwMDH2sXEcmwYMGr6OH4tHEJp3fHSmMhQsgOZ5BffY3hh+Pk8YuiphuHGb3RZF4KzA5NLJNAjS8EgJVxboL/wBGesHEzMQiUNMl2hkd0D8eEzbKp78GijuESTFMJlVHd86KZo/cmJVbExA1c+mzi1iCOemGFUbg/p5BTyHTNPMIhBUNgs54HVLCsjYhXUmiUPpPWpQZphmXAQmRRObOhgenpQUBWq7kIFBILj7P2L4X9+L6/K0+QloMCVr+MZ75HZT0kq4GFuB98YCEXss2yIUHYb2iOVBt4lHIMRLTSjPAxDGBAEf/390Dqeo2QgWVvYwZEQnTaHAzlZowBBFiCRSASqKRA53pHERrGgppgAJdQWNUPkl6xZxCYQCfQjDaOJiLBAFutQNoTSmS6OVZAtJxwop0EPp4vW9syZAeSjsYEEOPBjSgDbiEBYleyB7yVDh98pUSA4QhEMIQAoEgEU5DiAPlcAKwlQUQWLIU0kkxEuwE0BKBLG0HxUhBdEGGQYSHWkHO1Tf6OndoUiQDOQ1FaEmQI05YBB+dMo/GBwguSkECB20XAoW"
			$Code &= "GTJTQ1w2YWQ8dA+JFFMQ+NgS6EO1Nv78JGM4Q5BFip+Badh2/sES4QyBvlwQKaZBJYuTScIhjOx8GsIKBn0Hxsg26xEZhEngQFvTRQM+F8GdBgk11OwggXQDg8kwpYUSEEIIcKX34Slx0RfpAcpAVsHqBP/CBGvSH+jT/xHCMJP46gZXTujBJdATozS4E4qtEKG017DHRYHLNnwkMARLcbm1YAoIRPqBOUM4c3EHhzs7hZY6LPUdxgzRdkDQ+qEu0u+t4U/IIgMpQFQm20Zz19lvMsqIdXQvbCA41lPi1VJiTgmaETtnJAY4nGe3Yxg5FUpyj2nJHhJsQFHQdm0VwdvtKe6BcOjWs2tlQlGfNBJ1C3J5SSjVu9zFikDaELXiIASgUNVTwXR0O6HSOAsZGUHLFBeNxBjU6Clys85kpf8RuDV8UMI4dFUpyyanTA5IpxM0CLyZZzbBKsZgEECINJltLWAwl+tOBeL9R2YoG0WBahIZEmgKM0JgxMhbzvS/IbHOn4iEnH0Is7JY5uSNbpCqxEuyKAepu2cZ3nmLCnVfO+ZOdZLTxf12CCKTUyktIPQBE3c3RoaEkCuZY8m7oiYvTbGhFCS3Yt2xGm4AxbZjKBDOUCIDyRxnBhQrNntAnKhJXDmQSIlQTtPDQwh1CgkM7X8F+Er0EJYUURhCGnRaCyFftRFHheu8SDIcE6PIwRMkhe2FEeJFNpEW11iKIrCXxH6ydqAE6Plk9nMluaBiGOfzKwc6Y+t5gojN3wBMjUAIWEhbAYOiFKZjKnQFKonQmi9hrmoBBjPIEmFvwXV0OcVGtb8Z6FzYnVRAugV0T560JsloFwix1zYqikg6MSV0Wt/fLNLJ4a0F/FmuI0t6Vg/0DWGf4ooUykoO5nLUQoTB4mbyKLr+UZYlJa2KgCqCNX9gI0X9KOmrGCD5Ak2KiJS1lbO2I0JNok4VEE+oDIVEDSohDlOcOW+VQoXkIQja4XfnPNHPM1/vUBEEW1ss8ON+HQdB92jt0hgkMvCLxMEY4Onb/VzyhW/PFe3DCyQCRU+zYg3+Hhroxt0acImfxUyJhCRSNp9m3cmaz9wAR0WF9fwxhEcCA4A4MTCwPhODvCS22JlYHDAWQD3JdUvEuPp0hhNd+JFKgy5gM4JRsDmjMHpAFI0FWYbfVUCKTad0YjgmDUoSY331oehGnjuYr5Vkwcoe6OEIyXkggxL33+uwqvnofn0JW70gQe8QRL4OE3DQy1hBjUhHvgL4CA+HonXGi8QUhZhbLNQIBxGMZq4JEv0WbMlieFngP7V0H/03SvDLuEoJosyQ8iXyJmFQ+kr4otcpxviUQSx8uWgMaCwQGPR4koZbRfXg/TDf+/HUwkQCXQgNiBJPofQhnaQQmDueTniSRoDY8NPgGYPBAhZ0ax0EQ3y4q6oHAvfh0erDloCFNX6GHdHyVvFGRaxKRqL1hVZ0MhJgOyC/Bl6ulujaZuYzaENhBCS28BZYS/KJSdnDrDkCFIYXDY0MhdEwxU4BGEw5blB0Y50NYJFdPmgWV024WSVSWJM00eiqycZ/DJZDhqax9QXGRjzSzIZVHqz8jn7ohJCOLXf0mdxQcocgWKrhtPQsx0bxaSJw5bAR2SQ4IBLor9+poMjEbu/C0+gdf6c5L89TIItdxglO+T0vyREc2Hjq8ssmg4KeIQJaB+sRVcmBuVUSBeaPsPZgFoenNf/sEVifLy4gl40oWDtRtx5h9z/X/ghN6mE/sAbCi0TFofE51c3UdBZ3RTtBDAwQugVBTMX26FhS7gKBwDmfgzF0ONeKOUTTGOq3TEjV2xOPqMhVRPfD2Ye0TAsEgbgcBoGkwvyaz3V/XrGOe32jChBMnOYqowXMC0zcG7vheEG5DxUe8gz5xxwo4T6m"
			$Code &= "BTAIEeg5/KsznfnqyQPUmUQGvonVINkK4AvgDaOLgxGCE32HghsHHwcjBysHMwc7B0MHUwdjBHOHLgejB8MH4wICAXVtWbhWAogR5BJyEzkUHBWOzVRJngpHaaoIDpLFB0yODYMZ4CHgMZjE4GHggeDB4AHj22cG9gOHBKcGxwjnDPcQ9xjnIOcw50DlYC+ORYIdfhh2FsgFF5EYIhlEGhuJHBIdJEBJTClKUDZMVGNgEwhVU1a3M5InJuXWahKA8qE+5CbOJgl9qF8axIC9xE2JzZXywLXoMMB0axdUQRXCpy7U4oUCZv+CsahdST/vILdVEmBBuiadeD5Fxq4aXQvO/3RbByB1DeMB8hlW6AIi+uRz7cwk06ZHYNqU0nUtSSSLTb49KFDh4cPWDneJPkmD8FEEFQwLx5GKpP0L6YBy4H27tRj7dhbKw6pblwwSYUYfwAIsGNNy7iLbv1MBsjxCnIn6jl2Er9Dywi9MgKApz3gV9MLf/kt27AI1fhJczxQGjZ2dCFPI6xqTuemeeLukGGXKFOG6ZA6LkNG0KapM4gPKEsjivDSJEAzn6ErnkQYbLVJAWKpoqYci9lihUAJpyLVA+TxJ1BoW2bbHPpZcQO5yb9pU42iJ8VjxwCTJQQno7GCIg8q6FD5FmCcn5FryoD3rMrJHL7rcJUItAuo6Ih96/SgPzEoNbEwNCZiXWb8ETYt9rhI7iKHTeeYqVYCcv2FFRUTDTMqISpDP7ECEdYzuIM2B/lSo6HMPJ+sapsQVHmJQp3IN+ZQM6RwZi5AwtrAZw3TJzCjgH4hFUW3o8jnQLn0GfhxQA+sifhovIwxDA23+TDKZQlAXmEIk64QiYOtJudncEsT6gSnhZpD+UiVQjQ4w97Sg/+qYBalARSFLgxoEl3X0sY1LROwwueKF15CPMdHqDHX6KoIbDN2AsSH4McnuPBoC6wQOXQqeZRiIhti6vaki1tIEZgFUhtAgxCh1HZT1rsRx/BSUXkWOzUNJom4W3hrXdgkUApGAQWAUD4afarkB35Ah+2+GKmRrEx3QPaEm2U2AuWAMZYRN3reimyOryUfRBAxGk7YJ0HMZQrE8ykGWfg2a9MD7w+sUM3LnkxJtjFpbXbl7Qd31Am1GaXwJJIH9akLrDERoag0daUcP1JOJ5wLLWKiUr8QBgAjeRIg1DJgVUHvmj0LHXLDMHglOTMQQk3LBW4CBrESx2Olk2XlrWCKgVWyo8qGgX01SkqWdQ/GlXcxaFjwE3/gJ8AlACxThg8yCBtuIXVFKgap+kBJIFH5wlHqUdOgOilI3sI8zxwEkrzBsjPrgAknVVFULYIkYymhqH8EexAluZ51nW2nci0X4uQcn8KR/6OlKPeBnKdj7ViRnXPTIGQdoOERZcyXE3m5T7qLl6RiTClTz1jZAFFaSW8weUBNYnpu5dcIxaPxJXWE0BYUK8XUowIPggPsDIHdOrYjZw8NbmsDfCcLrakBB3xIsW2FJIhIjhihGDIBJIdBCizhEhQSI4SjjlAvuDcggTz+C/KqVGhQGFxLrpw4rxn6e7p+IkqjgLsWIgOHwdBISKMsSDBsJqKPIanBf9xnGkOhLb4FDiwSDkIbHIO+EW4RKR5khUFjHSZ1KKIROK7HVR8iBD4KMOCKM8Sj+OUwpgNH5cxLzZqULigaIB9zwKF8TxukCWsYlAgv3/gsPz/MLfLwGsHx8MHS1b4pH/zKIxG0FrDFSq33pyU2ocC9F0gp8CUQB8BAA6fumHkfMxfhBRsrpMdswicFSJFz3U9mdIa8GAfmD3nBgJ3Ue5KaSsqMPLPTwcgbOdmUaK/OkugzrWW9gDDnBdjVLXDZIA1VRkOByzmHBWznIds6oLEIkFJlgIyhLPTwcK4sxoS8UCh6kGpIU"
			$Code &= "mQD9AKggdE8KHQhRARTrJgohAhAciANEEiIEEQgJIu5L7MmiIGmqWDkTWdQ/BEySiQi5rvgI8LTgkOhI3p/hLVO+ksj/fBFV9o3JSqnBR6BppJlWETrCsgiDplXnO0LLP9CnUfJyXPo3zynOTfzxNEXvjEpBEBH3ygjB5zQGwNr/jYpY/vOKAQ0WB6GQmTozDDQDN32obzgozQ+q/UCTZyfoJma2Ly1EWBfIEWCTH7ydW1Zwx2rGOxhCbIE/QfbCIIAiukZ9AlrRoUSdLIMpm6bqGsCNCFAiCnXexgFN1+gf/CpEW11LgtDzQrwEtfvuBN/o6ow2QwkgxwcdGWjobl2cXJIgwEMDSA9FwaUelggZTBQLFYbbuLBJWuesGFqoWNP6CeUDCwv0KgaNBNUh4eXBkvYDwsBNrsmJ92LB1Us0JJJLVBQhklmDUSGlVoblBrZkCB0HpBwFvZBiQxjMHidaW3oQkA7MFC8MRMYaeyCaXNybLVkYLWluHXZhbGf0oI9zdD8PY2U9nG9+vWY8cj9ifXBrU1gltzdv3rUd5ggZdGVyFC/zsW5n6WhPIxVgB8UZCFAJEMEU4XPAEgdmHxlwCUAwCXDAGRAHChlgmQkgIaA/pkAzgAlAMiHgQQYkWEgYnJAEEwc7SHiRODjQHBEHokRoKImwtxGDxogJZkgh8IFEBFSK0Abw48iBK5F0IjREyA2JZBIkJKhQMCKEZkQh6IH7ElwmHCFQmMQHZlMZfAllPCHYSNAXkWwiLGa4EQwJRIxMzCH4gQOJUhISpICjSCORciIyRMQLiWISIiSkSAKRgiJCReTGJFpIGpGUIkNEejqJ1BITJGpIKpG0IgpEikqJ9BIFJFZOFg9AHCJEM3aJNhLMJA9IZpEmIqxEBoaJRhLsLrEiXkQenIljEn4kPkjckRsibkQuvIkOEo4kTk78E2IAUSQRkgCDbgBEcTGJwhxhiSESoiQBSIGRQSPikVkiGUeSInlEOdKORGkpibIXWJGJIklH8iJVvHQoXE0BAIh1kTUjypFlIiVEqgWJhRJFJOpyXSQdSJrkfUg9kdrIbZEtIrqBUI0STST63QACNBNJAMM3ACJzRDPGjkRjI4mmFAgwg5lDIeY3ACJbRBuWjkR7O4nWHGuJKxK2KFARiyJLTfYAyFeQF/J3JDdIzuRnSCeRrkBwh4lHEu5uAERfH4meHH+JPxLeOW8SLyS+UFAij0RP/uF3AOLBPkehyOH5kR8j0eSxfPGP5Ml8qY+R6fKZPkfZyLn5+R/IxfmlHyPl5JV81Y+RtfL1P5HN8q0+R+3InfndHyO95P1/I8Pko3zjj5GT8tM+R7PI8/5Hy8ir+esfI5vk23y7j5H7/MePkafy5z5Hl8jX+bcfI/f5zx8jr+TvfJ+Pkd/yvz5O/4qZJAXXGhcIj38SDa8bEP+3ypcYGRAEFfkg5x3NEEBAA/cYHxACFCYHGBwQIBL5mu4aEEO15MILQKzCQALfgSJCGSAYQgcgBkJhIGBCBCADQjEgMEINIAxDwSdZbiCdKxgSZXRnkwb/I0ELhnZwDNv+Yi/GDtqLtSKldGj1Ej5UABNf8F9CcxxlQQcMuRg9xy9MZBX+AtsuI6MgMwksBjQ/D0CfjYKUBRx3VIAjQmZgCViCecdwFN0lxILYG/vNvZEU3FvVqOt0APnXt+bTGFLOhyd87M3yc5+SpQ+QwAYx7ffbP+sPANXB/QT/xYMO+jB9A6/j9qCmJPj7uJhvBQqEfhqvZUOrLudnFlf61kMUOeMoqg/1EVhWAcdH0vH0nPGWbxg8NOj6xIPrvvxx7QSqKKXXgcsrkbyEvhJB3PJFtLo1G6zuOKpGIQ40ki2BL7P0fYt8tltph/JIwmebE+xoWECbupFtgznoQbib"
			$Code &= "G0oT9OWLYktLQzjceVB1GBWNRvzu2q0ebTlDKK36ZF4KaDjomMW/McdgdA5IQ/K9axezawJE+OvBuPrfng/WdOoOaElp0PGxDekKN68gcaM73vZSeUk8iiQH2TBIQUDDkIQKEH8sRbMtYZ0U67YcBCB3HonR7DyYbFFEOdPg45j/yMEh2I0UQQFee4rzFujcsTUgTmhFCYkObAUbgfhY6Mxe/IiBYJkURGwULokgdtJpXvgt6WzOkhp7E7Sy0hR1Ic5F5j7B4tPikj5OSdEwEh+RGQeLKOmgWaMSZBMd4bpvA/4sdQxvXyIjMNPnq3vwK24Y/60M+qIaOf1y0FUSo15hAvroInF2FwpDLLwAYzTrVit767w0ewDoOe8PR/1IA9lKRMKfUegbcErXUnQb9RriAzzoTHQ0KuZwPKNbEXYbAXvffZM5rwNJRMSJfxlAMHOwnG/4GDKxPS6L/nxLbOxt36SDyfqG/2o0h/yB9Ltx1KMVBn5JcY4y9hqWKXT9x4u48XuEIUGLBohDeJWmiHAaJH5EEURo68TkvZYkYLsCbkC5DF+aQl6di1hFVHuSBrj/S8GGSxDccwjMDiMyTZ8DxVU4uXW8LuIeemO4CH0wDoYeD4dYxek0UBpnVloIg7oMwccGQU/p3yTUg7h0KXMhow1OB0M+CR4k1A8JxwhYdTnOSabEERjFQ3LfBPbCAnRH+A8QH4sSdT69pMTwkxMFB1Ww7jTYBZNGGKiGNW0eHuVN6NQ5Aon9DvQYZOUBImUlSe4YYjR+EL/IrQfHSkCyDgJB9kYIAf7aOFOEMs1s6PVDrJvhdyiXRE969yWJyNxEH+j6YC4Ea8AfdzmQOHCOgz1RJAc8CHQVciUcVt1s0x2ERQTyByhDwe3dDM/8Uuns4XkP+giadVA/kU5NKP+QyJDqQcoQoxToL6uyPl8IlPfVs5maTGAs5VICwXcozQmxVC7O6S2lBFL9UHaGmlYbcIyUM+hWZxXIf6lgYu4FN7O4brfCgP389BIyIQ73xWq1YhHX9RoeNS2lC0BO/PJEC5kmL7G/45ZkOEYQMAJnI0SIkIGExqSYyRmxEo2yoMCjkv+RjauXtKYFFusFCoEgosRMayAgpLaksr2Hq2hKb+U1UIRyQW4VjO8wyohFsdEvhTMYJhAyPbMismYUK8CRgeQDchAwywSTI3oU92UURcXvENCRlddf4Wz0SAyRAHyPfxEERTrmJWwsh0SPyRC+bkiRDEUYK3vExpBo60gNTrTBt3gQUooFNGF5c0g58XFIesQgsDhfrC1YLud3ShBP3SUBUBgpyoIaHI0EE3xWOvwW0esC4cDP3185oOLNAWCaBGhs4JlZE0yJiWLYOeg9u4kFHCneSQEd1oleSIfffkuiiE4DWhDRFo5xhREIJHMTRjE7n4h2ikoasZr/x++awJKUX4J3UCBysVIQtT87AShzB4gcEZ9ARiq6eAUKOfdyy4jzKcb4iAi1j8ZEHuYpVf6KoF6DIssCSTEf95qV5AcpyhQjnAJ5MA8hOH5DIKI2HTe81V24CFxzeIIknQgpAlNIZUqI+gHezTK31geN0HQS6PNZFuex60k2KEjzpkzB9hDB+Ali63tSPIhcN1jBtcGJZ45FuYq0ZIYLUJy3j/LIBAvnBiAyRbgmKKLN6e3YbZn4CiKQp0RTayAgmmSZ5SCOvVBhOIHhd89WAVYt33SkJagUyETn+qi2hnEKFJJbDAGEkQ1Oq3JBjQqdRY0etk+hKWs2sRJABrykQpgTKHQWmchFGkPhB9DT7SkKz+kj/8JEA5hokuEaigPBSK0P0e1Jzyw+3QTZHxQDL8wo/xnIdDsJJAUM6Nkh6E5QUI3aMgKM/lF357bpZBtkAiEQWD3po9InAQnx6Nb2sjcu"
			$Code &= "E7i1hZKEhEKB430zKGMIRcAznRAOODRkIxIF8XMITdgsUPuuSV24TwxAdRMkPgkaD42pwZk7P8HMhKCtExAb6JXWxZHFjgwW1EUeK4mEakjUYCcLKVLoT3BPmnj5FVh6KexvGeZjDU6SUPj9gqokRShCqkfl+hpSn00B5OjRq833OHwdEDklgpUHFDxpmKthVEgoWKIORcI6JP4dbzENRYt+QnpT8kt/RIfZ/s7v1/kO+rInTtMps4MyBsmG+2FJZ2tSvxIhJynCKfrBitySBtkkS9aXINOSlOnk8elpHfc7POMRQBmxDqzSI4D+UQ4I6ZIRQAXyyBTqYuEfZBd24n2BcQGCQCAP/0/CIzrAnUzZdAhWQHhGDXCB+R49MU0SJPrJVvh4RIV+fEiDEaanlHDfdP5zTFuasfj969xrZGF8iVuBNP1R6PzxOpYf4CZZZuRM+gPxheaMRogOV//qfFvCcqVrOvATcyOjPCFqx2iHFLwtpAAjct1JjU5kaAiGqfI9TaGOPxiJAQZGWNIrtcYv6JMFKMcBB7K1SuFYMZ6UMpZEO0SCQRPokd9oK0UwuvF8KiT1EfLwnvuA6LWtFZGRVw0jEig1dANSdLYFD4MYAhASkE8leAIHjUj/SnH1i58nzVgzBIjnnNa0nMsoKgTJOfl2Rog6vkf8kD5RPlQ7VUNGR0axd7qyHhgQQ07XQ3NUFyRVte8xOTnP+SRz9RJe/D6aYSbCOcchPUNWRc4WXMpt2fd8JI6E7QoT6TcmCEXTvL8GJWREUva1l/j6TALUFHMgXHmH7EBy+SK5XxJyDcrHuTLYNSeZCzjoiYSTpc6srvWypc4IwJYitpn9mvMMw98RenXE1FIDKJhG++bMStH8QJvRZMGjBybN6OtvQonQolQ/kfmifyQLSgfBGNAk+QGhxothHSPJPAM1dKyApDnRd0tYsmookBZ7ZpvFSOQJdeq2GCyC6CBLBfodDIZKz2bFFr6IpDF1mHTkD48IKvmI9A7wFfmLJqJ051i+CEIDfpvuJOtOiWi61m4EnXtdE3xc+xAJyEQE6KPcyu4uGWhC6Gi2aSCs+JBmi1cg4XgxTmy/YEGm+UIVBlKTNEfKbHdTlPktuZABQ9yEU8djnFEN4kkhg30o9ltOKBJFwDhosUW4KRJfWftAFBGD/txyYr/QUL2vTSxZ/kuVUBElUxiiYXMI/ZqcUliUY4ToE+OMZQuVqS5RNp4jtEqpV0qNbCo0Ou8MZ/dRx06GnPvpUb8QNHdN6F5ZWLnZqL5EH8t6Zz4ELz2sullDCATxGvTLtxa9hEwUx1OoUPCSv5WRWMJluDXaIHbqSwi2pT/CWadeX166y7KlYAz/yUUhbekYBpUkQ5RNLxVdtVZtFTwyyiwBYQU5+Hb/Tw1V1KePXbC2nVXLqA2gslesyayuOLdpwqKvArXGSbtMF9nK6Ac4FMC5jELSgK5kVEVgd2Wlp8vYNolIjiuQ26Zoig8rGxqaWjOC7FaORBkhSfYriAoQk4JFLgkUQMB0mAuPGhwzrBYfFYpU3DKdUMuLpbD2RLLZQiIQe/f5zDt+E1By3rYEGCnXM8hEpNhA7UZlSAiWM6iLZBe8FoyBhlXgEiH0JApglMP6RwNCAfcVkWy8YI+p+xDA6shha5P930k//ORgfyEBrTrpRwRK12KkCTwnTfSp+Yjr1rIkFykxKEwlBk/kxJf1a4hMUyXIGF7RUfVj7E+w7cCU2iXB5EvagYQ7TjDhHyiUEdgbRK/QRwiFnvMGNUY0X1QKmSzcZofK6wRpBrLCLQZISQNWODUUDusKDlrlQKU8Avk50YewR86bGDVQTAqJejxcFUhCxCgKu0jBzX5yiO51XPCWlFRMIkgJddbKKPTpaC0Zr2Kg9Jv3bMtm"
			$Code &= "XsqiNNMVoywRAU8QCrNOjVho7aFl9BvW6MFIAh1DHP+6RktJxS9aHqoTGb3CpZ3+ewMH6PiAHYTrBd3+75bLnRQy00WzfQnpdSZRL6Xop+AQlRI1+THoEEcYiRNmtJFcWAceE0Ly4kGZJBsqMgsIBW5ihWeWzyOW89A7bgIcdDXo3ga0XFvmEjebMkuJpykxwumh85Z8QhxPycphjwdsuetU2yMKFyt7GPydvDwPUwgBbxx9O7MM8H7FNahCBLx0MvDwXi6lgEhGiUj4QqbG9yRFs0N/NLkPFEVBp7AWg/oTM3QNCg6qCN0gRonI6wmwneG0/x2QSAT32P05XywZmgzhQEwLneICYHyNBFkI/Q9FA07Y8EtIn2meBJP3BodOj0sMditNKNc3Vfg+MunESlnU4k9KugrL5zKnVDFwdD2de1WMNEwSOERNK88kUDOqKfQgddCdUbjPZ8dDvY0vxIO/zqeT6yudPsbfpzUXdBTpMZ5EC4N7k+YfsTsKtAqD78/ImD91JZc4U3Z+gn1mY5he+mnWG/lELQcQ++vBPotXW6RsUOUEQr8NxwNWQFDrpbcLBFoWDDnGdidI8smGwC+iIAHq6MZZt0aZgdAM+iipPduEBK+JF4pC8Ulqtk7WaZ9PBTswNiZFQlFEzR2RN0AU9kAIWwLAz4lQID3HQvDhO6NR1BKZygl69JHLy/baE27V6JoWBHP8bTAKEwK4/99hC0LDgkN1BX0Bv+sUhLG0EonZ5Au5UgSWPynsGgb/o7IdBkU5l3KgEwtBRHrzAUUGmxwJI+SOcl6NtDAz7bXHhZDglrCKdZh5O39El3MQ7GXUa/E/H0isOCd0WVCwqHPHB2IfZYnRVKYF02dA1tIskIcHCHIni0/TTI2UgquQhL9HwZnC+CjyWJYuAZ9jwIlCOCcHc+JIjcZ8CGNUUMcBcI8S6PT+IWxGCJTkFhsL6OT+/F3LA4IMKWcuNk55CtZuFA6dCHwEdBH95nVfHIAW6Orj3o02VgjSIPy4SYWQJ6SESWk3XqULgzgNDianeEQOywZduhy5pVNqxV9lOa4IwcxiaAF37HZQXwmLSXpFilINjUIwoZAaRYWDev9Ltjp2nsqEr9utCUG915hy6BuCVn4mQS9sJEQF61g5I4tA8H7yb5BwSD9SNShF4HfTTuK9Gd/UxSwvJcUghY1F/OiYteopTT6F4/5MIeFI2p159YXo81YXz7ajS9VWDTLiI4lgX1gFdYf0OkkMOcNyQxnUQxsddzdPKfsFgetPG8FAAkqNhJ6VRjonRlhxqRcpCs4tEafY6cVuhIYyHWAFh+wFkCDp3qkcfYWTFVfc5OtBMtPlLOmu4ypSkLEWbjh+ULTLCSjpJiuAFkGG0KS1QhmCEMeAVTqsQhT+p3MhSUdFPq6AQ/kPdeX/7iROgFLwkYfIw4ooGHWAFoiS0yu0GoQMsFKEDlu4XYSlXRjtWUgJgenrqiVJECDCmIsEboIK+UpacAPg6SrMu7BkkDIk7P4xxglHkwLEIk6UBNxEcZUEDpYIvoghlxFRImMgtpggJZlELJKIEJqAHZuAdp6BfRGQoALuInSiBMdEdqMe4iBupETq9Yl5p4hZ72Fjb3LFZdR0IJ3O6eeUGmseqSrpJWk53EbcncdrXo9AO3rx08x+QiPyYgjhUgfPcJVhfSEHdVctHw1t0sc9KGfnWGTjb2aZYmzWnM2E4VBthnmsSqIbHNjueQ9tYm9stFe9G5jbfDSKZQ5RZyiQvK0QHXR5cJEWaocbYa45+mPypLCBk3QhmRgbdTluax1vd1QgI9P6CltnedqU0oxFp9RGdxLrt4xwsnplvFnGfm1wgKsl7hj1lLBo4XDAAA=="

			Local $Var_Opcode = '0x89C04150535657524889CE4889D7FCB28031DBA4B302E87500000073F631C9E86C000000731D31C0E8630000007324B302FFC1B010E85600000010C073F77544AAEBD3E85600000029D97510E84B000000EB2CACD1E8745711C9EB1D91FFC8C1E008ACE8340000003D007D0000730A80FC05730783F87F7704FFC1FFC141904489C0B301564889FE4829C6F3A45EEB8600D275078A1648FFC610D2C331C9FFC1E8EBFFFFFF11C9E8E4FFFFFF72F2C35A4829D7975F5E5B4158C389D24883EC08C70100000000C64104004883C408C389F64156415541544D89CC555756534C89C34883EC20410FB64104418800418B3183FE010F84AB00000073434863D24D89C54889CE488D3C114839FE0F84A50100000FB62E4883C601E8C601000083ED2B4080FD5077E2480FBEED0FB6042884C00FBED078D3C1E20241885500EB7383FE020F841C01000031C083FE03740F4883C4205B5E5F5D415C415D415EC34863D24D89C54889CE488D3C114839FE0F84CA0000000FB62E4883C601E86401000083ED2B4080FD5077E2480FBEED0FB6042884C078D683E03F410845004983C501E964FFFFFF4863D24D89C54889CE488D3C114839FE0F84E00000000FB62E4883C601E81D01000083ED2B4080FD5077E2480FBEED0FB6042884C00FBED078D389D04D8D7501C1E20483E03041885501C1F804410845004839FE747B0FB62E4883C601E8DD00000083ED2B4080FD5077E6480FBEED0FB6042884C00FBED078D789D0C1E2064D8D6E0183E03C41885601C1F8024108064839FE0F8536FFFFFF41C7042403000000410FB6450041884424044489E84883C42029D85B5E5F5D415C415D415EC34863D24889CE4D89C6488D3C114839FE758541C7042402000000410FB60641884424044489F04883C42029D85B5E5F5D415C415D415EC341C7042401000000410FB6450041884424044489E829D8E998FEFFFF41C7042400000000410FB6450041884424044489E829D8E97CFEFFFF56574889CF4889D64C89C1FCF3A45F5EC3E8500000003EFFFFFF3F3435363738393A3B3C3DFFFFFFFEFFFFFF000102030405060708090A0B0C0D0E0F10111213141516171819FFFFFFFFFFFF1A1B1C1D1E1F202122232425262728292A2B2C2D2E2F3031323358C3'

		Else

			Local $Code = "RKcAAP8AAYPsDMdEJBxwOMMC6AUqMAqJGhiDxAwM6cdxGP9gAjws6O8ppBZliwg4ZyvAUAyJVP4UyA4IkBAiBH4MoScIEzQiEQR4MO3w6B5sbl6OIMOoLMIQIKQDbhw1NCLIIEKqZREIAhwRBBkRGpxUCeY5BUo8xClTaCGI6D+qsDIjJLAIJAQrT4giDDkiWvl6QymEcodKI2tWfbCNFCSn8ReeGilhGmILKB4JVleLfCQmdJIxTEA8hcnyLwD8g/kIcif3x1UBhfgCpG5JFLCABWalg+n+iTPKwQrz13fRw+EDuaTruhYGX17DV3dEEDAwD7bGDGnAbAEDrQjIdANBCqpJSAp1VPY//Cnzq0AAql/DUOgG3zPPxVhbBNn5/7gCRJYAMAd3LGEO7roDUQmZGcRt6I/0agBwNaVj6aOVZACeMojbDqS43D95Hh7V4MDZ0pcrTLYACb18sX4HLbgA55Edv5BkELfs8gAgsGpIcbnz3gBBvoR91Noa6wfk3W1RtZD0x4XTAINWmGwTwKhrAGR6+WL97MllAIpPXAEU2WwGcWMAPQ/69Q0IjcgAIG47XhBpTOQAQWDVcnFnotHyAwA8R9QES/2FDQHSa7UKpfqo1DVsAJiyQtbJu9tAD/m8rOOg2DJ1XN8ARc8N1txZPdEDq6ww2SY6gN5RgOTXAMgWYdC/tfS0ACEjxLNWmZW6A88Ppb24npACKAgAiAVfstkMxiQA6Quxh3xvLxEATGhYqx1hwT0ALWa2kEHcdgYAcdsBvCDSmCoDENXviYWx8B+1tgAGpeS/nzPUuAHooskHeDT5wA+OAKgJlhiYDuG7AA1qfy09bQiXAGxkkQFcY+b0OFFrn2JhQBzYMGWFTuHo8u0+lQaAe6UBG8H0CACCV8QP9cbZsABlUOm3Euq4vpCjAIi5/N8d3WJJDy3aFfOg04xlTNQC+1hhsk3OQC06dOC8AKPiMLvUQaXfDErXldjExADRpPv01tNq6QBpQ/zZbjRGiABnrdC4YNpzLQAEROUdAzNfTJDnAMl8Dd08cQVQ8kEcAicQQAu+hiAMyQEltWhXs4Vv6AnUAGa5n+Rhzg75Ad5emMnZKSLU0LAAtKjXxxc9s1k9gQ0ALjtcvbetbCy6wJQAuO22s7+aOwziOgOA0rF0OUfV6jyvd4SdFSbbwLIW3HMAEgtj44Q7ZJQDPmptDahaq3r4zw7kA53/CZMnroAKsZ4eB31EgA/w0qMIhwBo8gEe/sIGaQBdV2L3y2dlgAdxNmwZ5/BrbnYbANT+4CvTiVp6ANoQzErdZ2/fOLn5h+++jkMxtxfV2LBgHOij1kB+k9GhxMIA2DhS8t9P8Wd9u+ZXALym3Qa1P0s2ALJI2isN2EwbBwqv9koD4GB6BEE7w+8c31WOZ6jgjm4xeb4AaUaMs2HLGoMAZryg0m8lNuIAaFKVdwzMA0cAC7u5FgIiLyYBBVW+O7rFKPy9sgCSWrQrBGqzXACn/9fCMc/QtQCLntksHa7eW36wAGSbJvJj7JyjAGp1CpNtAqkGewkAPzYO64VnB3I4E1cABYJKv5UUegC44q4rsXs4GwC2DJuO0pINvgDV5bfv3Hwh3x/bC9TD04ZC4rDx+LMA3Whug9ofzRYAvoFbJrn24Xc5sG+CR7cY5lpgfnBqAA//yjsGZlwLPAERgJ5lj2muYvh50yZrYcUAbBZ44gqgAO7SDddUgwROAMKzAzlhJmenAPcWYNBNR2lJANt3bj5KatGuANxa1tlmC99AB/A72DdT4LypxZ4Au95/z7JH6f8HtTAc8r0QisK6yvKTALNTpqO0JAU2fdD2BgDXzSlX3lS/ZwDZIy56ZrO4SgBhxAIbaF2UKwBvKje+C7Shjj8Mw4DfBVqN7wItuQAPQTHAGYJiNjI/w1PIJCbF2QBF9Hd9hqcAWlbHlkFPCIoD2chJu8LRuOjv+nvLAPTjDE+1rE1+da4Aji2Dns8cmIcAURLCShAj2VMA"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "JHf454opCwFNDIP5BfCHHdQZzHyLzQsKP1bAv99F2PkHJ6WkPb37GnUJWAHtheYHQywQBB4Y6J7CkRhAHEeLsV+4+6XhUlqVAeyLVihCtD5fCBW5PM7zCCf44DGhAr2wCTlWZhgc/jFUagLoKeu+zq1qoIQPxsA1HwFe1hW1ragaHIYNRU4EnE0NHFUo/liyS/M4a1GIhydzhTlBwr0aJWQH0KOjAAl1BY1DAeteF4wiAiR9CXOJfAQKUXAduKlneQsTx++GcTs+6cRjRVAkmEgs9wLaGNKA4hBDwLvJuuGG78omUhwMIQghGJAEGYM47wg1SsHCLgfOiBS6W8UcgRpJBEFuDBAJ5xchUgWmakImRSM7UcMmsgc2jdoSB+KWQty9sLaJikkMpVoobzyDeNBIdB8hikDpKsxOFa2ElE6Hg4N6LIF0ETpTdQlnMHizIg69ot2LKFkxKi9CRSmVm48wgyAIweEMgb/K9EEWlkibfVYguH4U0HwWpD8G2+Ds67B5atIXKgLCjUICxLA+weC6CQyDfmzQA+zJACC4hRBCCPfhOCnRl+mNElavC7ABDkTYrAUp993wJ54T6I+EZEAxEg+3TzL+gNkfEzDldxSchYVDvGhMoSRXEMSR+ZMOErAQaFz7JHbFOQXJc2pP9zsCDHU2lPBLGQmhFXAgivfCUzH4FklQzfjpObTLYxuVfRFtdCxzMUoQDCCK9kEpXiQ+GP+SNLiJDLNOBiBnQeBCrNVyVpZiUpdCZaGxuw0GUVprO2YKnWhxSRRdzuBCoyBOc3mJjyPvKxTClTMYQ8Ig0M6rKfVgfci7VMjCiHfqxcIkvwyfTgZeyeJbrnLDC0GJ9+v5A69iUF2EJqfEUsXyKT4KuEFbsUi3AdH8VzCdgtz5uqxbYQq4w1QgrVuM7wKhsT0kUq2NMZBKrvGmugoQyenoJI9xSwsqB6tGZ3f6W6w2WEtlg8ECO7AMdgepgEkYjWBQJFYMdzVpioiylGopUfGs6EmCZF8xZHiBixCkIYCL5rk6KEaytSO3dB8lm/yLipFtPp40KPIDW1jLu2cuoq7BB3UmO1f8tCGhnAPA6PK9UZISW4qTmlDlxxQfOWG86OC8kVlII0/IHwp1GYMlhOYT9Jr2qpEsOhbrimGhiBJRWpFfDML15ylAgOsptk4iESNm9RMY9mMDFEDoEOUH1USQCFZ20DTtinV0BS4pTxOaplAQdAGfbWajppUmOdgOEICGRQwWAnULVui13pFZSoVQBXRFmbiILPzdRBCsqmSiMPz90+L40+L0SSR+6Ogoc5QoUwzXWsBQiUZsyQZcImKa5zkXIVtdZEtiSja9tJT2FoSRn0YYQat/C3GTqVQrSLKJhYGxpootw10ekgRtVzGjjdkhMh8jM+9R8gk+RwrIC9Hr7uTZqH2l5rvbmpwTJ968erfkfvNcThrEbgK/D5RnRS0iQqb9CP9cGOi+un1AEJlNkP7g6AXj1his9cIgMclXitWvZMiHvOQCA4A4MTWgFxMPOCRwNA0V5H05WM/sBY1B/l8OQiATTnM5fdN1+C4su11vbFgkKIEkskgksxvaWEt4zNUjF/6lxH4TqwWay32EYIDr99vrtqg5mX4N8wIXz/ShaDqLCRhIAI4ID4ePUAF7EPUHHBWNLEv4GRkHLHkRuAlJp7KgHGujJBwEIRRhAPsIdQWJRbgyWMPwOSjQjFa9MRJSMa5vKBIrhML4iXcc4UMYfkS7XjDNHTofuFIY7AgquA1h4DpQjVNCvlb+nAxMSAhUuhcYuKuqAvfhP9Hqrz5Mvc14LEQ6GfrYT3oLJVPRSWgSa3lJyBJzZtAkRKJTBmsWx4axABABagSJt5rQBb5QUb+3elGOEG4SzAvuOC6BVXYQRggLDHRN0mjsR70vZIlB0GkUPYnKm2hGtwkESGJWwibc/m8jVRxXIqqY7I5RhD0snYDGRiQI6FkZ3xJeW3TI3MHoJpW4KUYYaJAq+JhR5CFv"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "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"
			$Code &= "HJz8koApUjQnVxhiz9UgyVFSdAf+nF6I4iQ7tN9tAQYghomF4PTYdV4jJMa4OCbhjklyP7bnaXhjhBBmGA47biZ0Dw9ijAcw61e86GQbMgglkUgKEJWHyeOOhG4CO18cdFdGyCMVBy2ZU4v62hsUhnHtuU+EOf8pZqXQGhtRGCDAlBK3FmliFFAQS14JF1v0+kgraKHEHFOg4gGJ6/dLE1D3Re0DviiEs1w/dfwJPxp9LihnnI87QcV0Iw8LXWPoautUfGsUyLAep/nb6JuQdQNF0CtGBFBSnl6QTfNr145q4SkfJ2B2dDG1BJ0tiCJTvWEVVqj4VC8p2gKH+IYC6w9dxKHJItl4QycGh8QtnwqwBkETdAxCtgh8oWEOdQdEDIzpBL9KFvUDDuFALzALWBGwZQYISoHigFE+AcoSVzwMe9DqVhEsdQQtBtK39BlOi1KUBaCx/qsilPueudQyYLUQbhikvooiEnQ9+ycedDa/jBUv/EC3JDEKvo6kIE5BVv0kQb//0Gstdj8S++8rmVRHVpVShW/EQ4tzVt9EuUaDfuK1QuKHaxGjPgpLCvir9iMldSdsQyLphRJNDFfuDBPeFztMRpl9yFn9UItDCRDoxekYpRJfJMcGpmqlIx6gsdN78L05Fsd2JQUoUAGpwBYhYaf6QfjdLEe7ef6h6DIseAf6UQGMSvxbYOIzBYl+LF9tIi/yVPIgMBn272oNDRPnbgX3x0GtU5L/Klt0780KrS54jhJ2QVO/ABsEczWKFGAwEAIZ/4E05wFRwz3ay8fmeQA5+3UDQesRhAfSdAQxyYMJurYpAynKidFAOxp4csaRfUDkCl1Jw2bIV0TKInvWN0e/CL3kaHWAYn88CFtzgi37/zoYQO4fViZ0T5IEPInBuXIGZzgpyMJfx9V98a8gTPgkCHLgA3c4ileft+ixiFQN/MHu7kFoiSIcQXPnjeFoIZDWYSrHaEWF6Cj/zGuLWEsKKjMbMOgWJQFDCHMpdgRIA/R40DuDPmhIuhBeX6fYDlMUVxMZBWOs5Y2h705OuDwnXpk/X3+dzH7ay1ZsIyECGoM4DVVAtXg8oeAJLGCQJV6KMslRXSLZU1ZCDuqcQt3dFtFlXorb84Je4UB5jSIVkJW9aXsLQRVOKHpwjlH/0Ia3CwzQdUg6Uy40Yb9wi+o7hPQk1Uu5cploIKVc/LZtWrFEqnUbZiYjVy3uy5uGoJmX8Y4iZijzpZxQ/KfoJIVeDYdDTI3ry9Faj6CNNvqTabxF3wDcLCnYLaAYwfgKAo2Ehgot2GuBglBwRoFU6Rj5gJSOhjNWUIxsKcQMMmSMYU5sUsUYkLhDNI6/6veJmxrwyv9B8zRgGHFaHOOyS+zK5hqdcxtEGpiHE78WuabbnXFI2U5ILUf9MAj5Jw91/vA/+r8S5nRkCQHImJH5GLXhb4hpwSsrHegPSQihEetiWrLh/0ziSFkAEBqkfJk7FgOsIgLIWln/4H+wll2LgLOMgFKNgcaICTuOEbkQZo8QEpAityBEkUShyIncEZSSscMJBZMCYSTZRMGUBMWXCMuI1pkILJoIipsR1xCmnCLKIImdICqeRDOCihyfRrmjNjLPRwllJHZLWFRx4WNvcsVl1uJaf7urnhpoa5Qe8v9kPoQcWliiq70/zu31qjstnb146eaIgkDchCNOUb4j2MhGkErPYjTrtA/ZcCphTvoOf64tPhtt5o4oe2fPWGTHb2YzYmytOdcI622hkHlZSkQlOeLceW0fYm9saVd6NKKPmLZ8indl71RnZCh5JAgddCR5cCBahpFhrs76Y3ypsCCTSHSjRhsOdW5rR293VSA0I+/Ci2dPPqncSEXK3nRudxK7jHtwJHplVFyMY8aSbXCUqy/uGPWUxGjrcMAA"

			Local $Var_Opcode = '0x89C0608B7424248B7C2428FCB28031DBA4B302E86D00000073F631C9E864000000731C31C0E85B0000007323B30241B010E84F00000010C073F7753FAAEBD4E84D00000029D97510E842000000EB28ACD1E8744D11C9EB1C9148C1E008ACE82C0000003D007D0000730A80FC05730683F87F770241419589E8B3015689FE29C6F3A45EEB8E00D275058A164610D2C331C941E8EEFFFFFF11C9E8E7FFFFFF72F2C32B7C2428897C241C61C389D28B442404C70000000000C6400400C2100089F65557565383EC1C8B6C243C8B5424388B5C24308B7424340FB6450488028B550083FA010F84A1000000733F8B5424388D34338954240C39F30F848B0100000FB63B83C301E8CD0100008D57D580FA5077E50FBED20FB6041084C00FBED078D78B44240CC1E2028810EB6B83FA020F841201000031C083FA03740A83C41C5B5E5F5DC210008B4C24388D3433894C240C39F30F84CD0000000FB63B83C301E8740100008D57D580FA5077E50FBED20FB6041084C078DA8B54240C83E03F080283C2018954240CE96CFFFFFF8B4424388D34338944240C39F30F84D00000000FB63B83C301E82E0100008D57D580FA5077E50FBED20FB6141084D20FBEC278D78B4C240C89C283E230C1FA04C1E004081189CF83C70188410139F374750FB60383C3018844240CE8EC0000000FB654240C83EA2B80FA5077E00FBED20FB6141084D20FBEC278D289C283E23CC1FA02C1E006081739F38D57018954240C8847010F8533FFFFFFC74500030000008B4C240C0FB60188450489C82B44243883C41C5B5E5F5DC210008D34338B7C243839F3758BC74500020000000FB60788450489F82B44243883C41C5B5E5F5DC210008B54240CC74500010000000FB60288450489D02B442438E9B1FEFFFFC7450000000000EB9956578B7C240C8B7424108B4C241485C9742FFC83F9087227F7C7010000007402A449F7C702000000740566A583E90289CAC1E902F3A589D183E103F3A4EB02F3A45F5EC3E8500000003EFFFFFF3F3435363738393A3B3C3DFFFFFFFEFFFFFF000102030405060708090A0B0C0D0E0F10111213141516171819FFFFFFFFFFFF1A1B1C1D1E1F202122232425262728292A2B2C2D2E2F3031323358C3'
		EndIf
		$Var_Opcode = Binary($Var_Opcode)
		Local $CodeBufferMemory = __MemVrAlloc(0, BinaryLen($Var_Opcode), 0x1000, 0x40)
		Local $CodeBuffer = DllStructCreate("byte[" & BinaryLen($Var_Opcode) & "]", $CodeBufferMemory)
		DllStructSetData($CodeBuffer, 1, $Var_Opcode)
		Local $CodeBufferPtr = DllStructGetPtr($CodeBuffer)
		Local $B64D_State = DllStructCreate("byte[16]")
		Local $Length = StringLen($Code)
		Local $output = DllStructCreate("byte[" & $Length & "]")
		DllCall($g___User32DLL, "int", 'CallWindowProc', "ptr", $CodeBufferPtr + ((StringInStr($Var_Opcode, "89F6") - 3) / 2), "str", $Code, "uint", $Length, "ptr", DllStructGetPtr($output), "ptr", DllStructGetPtr($B64D_State))
		Local $ResultLen = DllStructGetData(DllStructCreate("uint", DllStructGetPtr($output)), 1)
		Local $Result = DllStructCreate("byte[" & ($ResultLen + 16) & "]")
		Local $Ret = DllCall($g___User32DLL, "uint", 'CallWindowProc', "ptr", $CodeBufferPtr + ((StringInStr($Var_Opcode, "89C0") - 3) / 2), "ptr", DllStructGetPtr($output) + 4, "ptr", DllStructGetPtr($Result), "int", 0, "int", 0)
		__MemVrFree($CodeBufferMemory, 0, 0x8000)
		$Var_Opcode = 0
		Local $Opcode = String(BinaryMid(DllStructGetData($Result, 1), 1, $Ret[0]))
		$Z_DefInit = (StringInStr($Opcode, "FF01") + 1) / 2
		$Z_DefInit2 = (StringInStr($Opcode, "FF02") + 1) / 2
		$Z_Def = (StringInStr($Opcode, "FF03") + 1) / 2
		$Z_DefEnd = (StringInStr($Opcode, "FF04") + 1) / 2
		$Z_DefBound = (StringInStr($Opcode, "FF05") + 1) / 2
		$Z_InfInit = (StringInStr($Opcode, "FF21") + 1) / 2
		$Z_InfInit2 = (StringInStr($Opcode, "FF22") + 1) / 2
		$Z_Inf = (StringInStr($Opcode, "FF23") + 1) / 2
		$Z_InfEnd = (StringInStr($Opcode, "FF24") + 1) / 2
		$Opcode = Binary($Opcode)
		$Z_BufferMemory = __MemVrAlloc(0, BinaryLen($Opcode), 0x1000, 0x40)
		$Z_Buffer = DllStructCreate("byte[" & BinaryLen($Opcode) & "]", $Z_BufferMemory)
		DllStructSetData($Z_Buffer, 1, $Opcode)
		$Z_BufferPtr = DllStructGetPtr($Z_Buffer)
		$Z_DefInit += $Z_BufferPtr
		$Z_DefInit2 += $Z_BufferPtr
		$Z_Def += $Z_BufferPtr
		$Z_DefEnd += $Z_BufferPtr
		$Z_DefBound += $Z_BufferPtr
		$Z_InfInit += $Z_BufferPtr
		$Z_InfInit2 += $Z_BufferPtr
		$Z_Inf += $Z_BufferPtr
		$Z_InfEnd += $Z_BufferPtr
		$Z_Alloc_Callback = DllCallbackRegister("__ZL_Alloc", "ptr:cdecl", "ptr;uint;uint")
		$Z_Free_Callback = DllCallbackRegister("__ZL_Free", "none:cdecl", "ptr;ptr")
		OnAutoItExitRegister("__ZL_Exit")
	EndFunc

	Func __ZL_GZUncompress($Data)
		If Not IsDllStruct($Z_Buffer) Then __ZL_Startup()
		Local $Stream = DllStructCreate('ptr next_in;uint avail_in;uint total_in;ptr next_out;uint avail_out;uint total_out;ptr msg;ptr state;ptr zalloc;ptr zfree;ptr opaque;int data_type;uint adler;uint reserved')
		DllStructSetData($Stream, "zalloc", DllCallbackGetPtr($Z_Alloc_Callback))
		DllStructSetData($Stream, "zfree", DllCallbackGetPtr($Z_Free_Callback))
		DllCall($g___User32DLL, "int", 'CallWindowProc', "ptr", $Z_InfInit2, "ptr", DllStructGetPtr($Stream), "int", 16 + 15, "int", 0, "int", 0)
		Local $SourceLen = BinaryLen($Data)
		Local $DestLen = $SourceLen * 2
		Local $Source = DllStructCreate("byte[" & $SourceLen & "]")
		Local $Dest = DllStructCreate("byte[" & $DestLen & "]")
		Local $DestPtr = DllStructGetPtr($Dest)
		DllStructSetData($Source, 1, $Data)
		DllStructSetData($Stream, "next_in", DllStructGetPtr($Source))
		DllStructSetData($Stream, "avail_in", $SourceLen)
		Local $Ret = Binary(""), $Error
		Do
			DllStructSetData($Stream, "next_out", $DestPtr)
			DllStructSetData($Stream, "avail_out", $DestLen)
			$Error = DllCall($g___User32DLL, "int", 'CallWindowProc', "ptr", $Z_Inf, "ptr", DllStructGetPtr($Stream), "int", 0, "int", 0, "int", 0)[0]
			If $Error = 2 Or $Error < 0 Then
				DllCall($g___User32DLL, "int", 'CallWindowProc', "ptr", $Z_InfEnd, "ptr", DllStructGetPtr($Stream), "int", 0, "int", 0, "int", 0)
				Return SetError($Error, 0, $Ret)
			EndIf
			Local $AvailOut = DllStructGetData($Stream, "avail_out")
			$Ret &= BinaryMid(DllStructGetData($Dest, 1), 1, $DestLen - $AvailOut)
		Until $AvailOut <> 0
		DllCall($g___User32DLL, "int", 'CallWindowProc', "ptr", $Z_InfEnd, "ptr", DllStructGetPtr($Stream), "int", 0, "int", 0, "int", 0)
		Return $Ret
	EndFunc
#EndRegion

