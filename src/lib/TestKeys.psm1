function Test-CtrlKey {
    # key code for Crl key:
    $key = 17
      
    # this is the c# definition of a static Windows API method:
    $Signature = @'
      [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
      public static extern short GetAsyncKeyState(int virtualKeyCode); 
  '@
  
    Add-Type -MemberDefinition $Signature -Name Keyboard -Namespace PsOneApi
    [bool]([PsOneApi.Keyboard]::GetAsyncKeyState($key) -eq -32767)
  }