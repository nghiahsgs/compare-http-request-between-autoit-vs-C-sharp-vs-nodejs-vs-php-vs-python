#include <_HttpRequest.au3>


Func _TimeStampUNIX_ms($iYear = @YEAR, $iMonth = @MON, $iDay = @MDAY, $iHour = @HOUR, $iMin = @MIN, $iSec = @SEC)
    Local $stSystemTime = DllStructCreate('ushort;ushort;ushort;ushort;ushort;ushort;ushort;ushort')
    DllCall('kernel32.dll', 'none', 'GetSystemTime', 'ptr', DllStructGetPtr($stSystemTime))
    $iMSec = StringFormat('%03d', DllStructGetData($stSystemTime, 8))
    Local $nYear = $iYear - ($iMonth < 3 ? 1 : 0)
    Return ((Int(Int($nYear / 100) / 4) - Int($nYear / 100) + $iDay + Int(365.25 * ($nYear + 4716)) + Int(30.6 * (($iMonth < 3 ? $iMonth + 12 : $iMonth) + 1)) - 2442110) * 86400 + ($iHour * 3600 + $iMin * 60 + $iSec)) * ($iMSec ? 1000 : 1) + $iMSec
EndFunc

$time_1 = _TimeStampUNIX_ms()

For $i = 0 To 9
	$data=_HttpRequest(2,'http://google.com')
Next
$time_2 = _TimeStampUNIX_ms()

MsgBox(0,0,'total time: '&($time_2-$time_1)/10/1000 &' seconds')