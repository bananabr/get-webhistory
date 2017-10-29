Param 
( 
    [string]$ComputerName = "", 
    [string]$UserName = "",
	[boolean]$Verbose=$false
)

Function Get-IniContent {  
    <#  
    .Synopsis  
        Gets the content of an INI file  
          
    .Description  
        Gets the content of an INI file and returns it as a hashtable  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2014/12/11 - Typo (Thx SLDR) 
                                         Typo (Thx Dave Stiff) 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Collections.Hashtable  
          
    .Parameter FilePath  
        Specifies the path to the input file.  
          
    .Example  
        $FileContent = Get-IniContent "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent  
      
    .Example  
        $inifilepath | $FileContent = Get-IniContent  
        -----------  
        Description  
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent  
      
    .Example  
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"  
        C:\PS>$FileContent["Section"]["Key"]  
        -----------  
        Description  
        Returns the key "Key" of the section "Section" from the C:\settings.ini file  
          
    .Link  
        Out-IniFile  
    #>  
      
    [CmdletBinding()]  
    Param(  
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath  
    )  
      
    Begin  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
          
    Process  
    {  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"  
              
        $ini = @{}  
        switch -regex -file $FilePath  
        {  
            "^\[(.+)\]$" # Section  
            {  
                $section = $matches[1]  
                $ini[$section] = @{}  
                $CommentCount = 0  
            }  
            "^(;.*)$" # Comment  
            {  
                if (!($section))  
                {  
                    $section = "No-Section"  
                    $ini[$section] = @{}  
                }  
                $value = $matches[1]  
                $CommentCount = $CommentCount + 1  
                $name = "Comment" + $CommentCount  
                $ini[$section][$name] = $value  
            }   
            "(.+?)\s*=\s*(.*)" # Key  
            {  
                if (!($section))  
                {  
                    $section = "No-Section"  
                    $ini[$section] = @{}  
                }  
                $name,$value = $matches[1..2]  
                $ini[$section][$name] = $value  
            }  
        }  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"  
        Return $ini  
    }  
          
    End  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
}

function Get-SqliteConnect($db_path){
    $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $con.ConnectionString = "Data Source=$db_path"
    $con.Open()
    return $con
}

function sqliteQuery($con, $query){
    $sql = $con.CreateCommand()
    $sql.CommandText = $query
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
    $data = New-Object System.Data.DataSet
    [void]$adapter.Fill($data)
	$sql.Dispose()
    return $data
}

function Get-OperatingSystemMajorVersion(){
    return [convert]::ToInt32(((Get-WmiObject -class Win32_OperatingSystem -ComputerName $hostname).Version.Split('.'))[0].toString())
}

function Get-ChromeLocalStateObject($filepath){
	$json = Get-Content $filepath | Out-String
	$json = $json -replace "`"`":","`"unamed`":" | ConvertFrom-Json
	return $json
}

if($ComputerName.length -eq 0){
    $hostname = $env:computername
}else{
	$hostname = $ComputerName
}

Add-Type -Path "C:\Program Files\System.Data.SQLite\2010\bin\System.Data.SQLite.dll"
$now = [DateTime]::Now.ToUniversalTime().toString('yyyyMMddHHmmssffff')

#Google Chrome
#History file paths
$xp_db_remote_file_path = "\\$hostname\C$\Documents and Settings\$UserName\Local Settings\Application Data\Google\Chrome\User Data\"
$xp_br_db_remote_file_path = "\\$hostname\C$\Documents and Settings\$UserName\Configurações locais\Dados de aplicativos\Google\Chrome\User Data\"
$vista_db_remote_file_path = "\\$hostname\C$\Users\$UserName\AppData\Local\Google\Chrome\User Data\"
#Local state file paths
$xp_db_local_state_file_path = "\\$hostname\C$\Documents and Settings\$UserName\Local Settings\Application Data\Google\Chrome\User Data\Local State"
$xp_br_local_state_file_path = "\\$hostname\C$\Documents and Settings\$UserName\Configurações locais\Dados de aplicativos\Google\Chrome\User Data\Local State"
$vista_local_state_file_path = "\\$hostname\C$\Users\$UserName\AppData\Local\Google\Chrome\User Data\Local State"

$json=Get-Content "C:\Users\danielb.santos\AppData\Local\Google\Chrome\User Data\Local State"
$chrome_history_found=$false
if(Test-Path $vista_local_state_file_path){
	if($Verbose){Write-Host "Windows Vista+ Google Chrome local state file detected"}
	$local_state = Get-ChromeLocalStateObject($vista_local_state_file_path)
	$profile = $local_state.profile.last_used
	if($profile -eq $nil){ $profile = "Default" }
	if($Verbose){Write-Host "Last Google Chrome profile used was $profile"}
	if(Test-Path "$vista_db_remote_file_path\$profile\History"){
		$chrome_history_found=$true
		$db_remote_file_path = "$vista_db_remote_file_path\$profile\History"
		if($Verbose){Write-Host "Windows Vista+ Google Chrome history file detected"}
	}
}else{
	if(Test-Path $xp_br_local_state_file_path){
		if($Verbose){Write-Host "Windows XP Google Chrome local state file detected"}
		$local_state = Get-ChromeLocalStateObject($xp_br_local_state_file_path)
		$profile = $local_state.profile.last_used
		if($profile -eq $nil){ $profile = "Default" }
		if($Verbose){Write-Host "Last Google Chrome profile used was $profile"}
		if(Test-Path "$xp_br_db_remote_file_path\$profile\History"){
			$chrome_history_found=$true
			$db_remote_file_path = "$xp_br_db_remote_file_path\$profile\History"
			if($Verbose){Write-Host "Windows XP Google Chrome history file detected"}
		}
	}else{
		if(Test-Path $xp_db_local_state_file_path){
			if($Verbose){Write-Host "Windows XP Google Chrome local state file detected"}
			$local_state = Get-ChromeLocalStateObject($xp_db_local_state_file_path)
			$profile = $local_state.profile.last_used
			if($profile -eq $nil){ $profile = "Default" }
			if($Verbose){Write-Host "Last Google Chrome profile used was $profile"}
			if(Test-Path "$xp_db_remote_file_path\$profile\History"){
				$chrome_history_found=$true
				$db_remote_file_path = "$xp_db_remote_file_path\$profile\History"
				if($Verbose){Write-Host "Windows XP Google Chrome history file detected"}
			}
		}else{
			if($Verbose){Write-Host "No Google Chrome history file found"}
		}
	}
}

if($chrome_history_found){
	$db_local_file_path = "$(pwd)\$UserName.$hostname.$now.chrome.history.sqlite"
	Copy-Item -Path $db_remote_file_path -Destination $db_local_file_path -Force
	$con = Get-SqliteConnect $db_local_file_path
	$query = "SELECT datetime(visits.visit_time / 1000000 + (strftime('%s', '1601-01-01')), 'unixepoch') AS datetime,urls.title AS title,urls.url AS url FROM visits INNER JOIN urls ON urls.id=visits.url"
	$chrome_history =  sqliteQuery $con $query
	$con.Close()
}

#Firefox
$xp_ini_filepath="\\$hostname\C$\Documents and Settings\$UserName\Application Data\Mozilla\Firefox\profiles.ini"
$xp_br_ini_filepath="\\$hostname\C$\Documents and Settings\$UserName\Dados de aplicativos\Mozilla\Firefox\profiles.ini"
$vista_ini_filepath="\\$hostname\C$\Users\$UserName\AppData\Roaming\Mozilla\Firefox\profiles.ini"

$firefox_history_found=$false
if(Test-Path $vista_ini_filepath){
	$firefox_history_found=$true
	if($Verbose){Write-Host "Windows Vista+ Mozilla Firefox init file detected"}
	$IniFileContent = Get-IniContent $vista_ini_filepath
	$vista_db_remote_file_path = "\\$hostname\C$\Users\$UserName\AppData\Roaming\Mozilla\Firefox\$($IniFileContent.Profile0.Path.replace('/','\'))\places.sqlite"
	$db_remote_file_path = $vista_db_remote_file_path
}else{
	if(Test-Path $xp_ini_filepath){
		$firefox_history_found=$true
		if($Verbose){ Write-Host "Windows XP Mozilla Firefox init file detected" }
		$IniFileContent = Get-IniContent $xp_ini_filepath
		$xp_db_remote_file_path = "\\$hostname\C$\Documents and Settings\$UserName\Application Data\Mozilla\Firefox\$($IniFileContent.Profile0.Path.replace('/','\'))\places.sqlite"
		$db_remote_file_path = $xp_db_remote_file_path
	}else{
		if(Test-Path $xp_br_ini_filepath){
			$firefox_history_found=$true
			if($Verbose){ Write-Host "Windows XP Mozilla Firefox init file detected" }
			$IniFileContent = Get-IniContent $xp_br_ini_filepath
			$xp_db_remote_file_path = "\\$hostname\C$\Documents and Settings\$UserName\Dados de aplicativos\Mozilla\Firefox\$($IniFileContent.Profile0.Path.replace('/','\'))\places.sqlite"
			$db_remote_file_path = $xp_db_remote_file_path
		}else{
			if($Verbose){Write-Host "No history Mozilla Firefox init file found"}
		}
	}
}

if($firefox_history_found){
	$db_local_file_path = "$(pwd)\$UserName.$hostname.$now.firefox.history.sqlite"
	Copy-Item -Path $db_remote_file_path -Destination $db_local_file_path -Force
	$con = Get-SqliteConnect $db_local_file_path
	$query = "SELECT datetime(moz_historyvisits.visit_date / 1000000, 'unixepoch','localtime') AS datetime,moz_places.title AS title,moz_places.url AS url FROM moz_historyvisits INNER JOIN moz_places ON moz_places.id=moz_historyvisits.place_id "
	$firefox_history =  sqliteQuery $con $query
	$con.Close()
}

#Output
if($firefox_history_found -and $chrome_history_found){
	if($Verbose){ Write-Host "Here is Firefox and Chrome merged history" }
	return $($chrome_history.tables.rows + $firefox_history.tables.rows | Sort datetime)
}else{
	if($chrome_history_found){
		if($Verbose){ Write-Host "Here is your Chrome history" }
		return $chrome_history.tables.rows | Sort datetime
	}else{
		if($firefox_history){
			if($Verbose){ Write-Host "Here is your Firefox history" }
			return $firefox_history.tables.rows | Sort datetime
		}else{
			if($Verbose){ Write-Host "No supported files detected" }
			Exit 0
		}
	}
}