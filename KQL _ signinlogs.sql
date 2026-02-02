###

let n = 30; // We define our timeframe here
// Query is gonna start here →
//1. Unique Device Inventory (The Essential List)
Most Direct way to see every unique device that has successfully touched your environment. It uses dcount for efficiency and make_set to show which users were on which device.

SigninLogs
| where TimeGenerated > ago(n * 1d)
| where ResultType == 0 // Successes only
| extend DeviceId = tostring(DeviceDetail.deviceId), 
         DeviceName = tostring(DeviceDetail.displayName),
         OS = tostring(DeviceDetail.operatingSystem)
| where isnotempty(DeviceId)
| summarize 
    FirstSeen = min(TimeGenerated), 
    LastSeen = max(TimeGenerated), 
    UserCount = dcount(UserPrincipalName), 
    Users = make_set(UserPrincipalName) 
    by DeviceId, DeviceName, OS
| sort by LastSeen desc

//////////////////////////////////////////////////////////////////////////////

//2. Cross-Referencing Devices with Security Compliance
If you are managing devices via Intune or Defender, you likely want to know which "unmanaged" or "non-compliant" devices are getting in. This query leverages the DeviceDetail properties.

let n = 7; 
SigninLogs
| where TimeGenerated > ago(n * 1d)
| extend TrustType = tostring(DeviceDetail.trustType),
         IsCompliant = tostring(DeviceDetail.isCompliant),
         DeviceId = tostring(DeviceDetail.deviceId)
| summarize 
    DeviceName = any(tostring(DeviceDetail.displayName)),
    AppsAccessed = make_set(AppDisplayName) 
    by DeviceId, TrustType, IsCompliant
| order by IsCompliant asc

//////////////////////////////////////////////////////////////////////////////

3. High-Risk Device Identification (Shared Devices)
From a security logic standpoint, a single device being used by many different users in a short window is a high-risk indicator (potential kiosk, terminal server, or compromised jump box).

let n = 14;
SigninLogs
| where TimeGenerated > ago(n * 1d)
| extend DeviceId = tostring(DeviceDetail.deviceId)
| where isnotempty(DeviceId)
| summarize DistinctUsers = dcount(UserPrincipalName) by DeviceId, tostring(DeviceDetail.displayName)
| where DistinctUsers > 1 // Adjust threshold as needed
| sort by DistinctUsers desc

//////////////////////////////////////////////////////////////////////////////
4. Browser vs. Rich Client Device Fingerprinting
Sometimes the DeviceId isn't populated (e.g., personal browsers). This query groups by the User Agent and IP to identify "shadow" devices that aren't officially registered but are accessing O365.

let n = 30;
SigninLogs
| where TimeGenerated > ago(n * 1d)
| extend Browser = tostring(DeviceDetail.browser)
| summarize 
    TotalSignIns = count(), 
    LatestIP = arg_max(TimeGenerated, IPAddress) 
    by UserPrincipalName, UserAgent, Browser
| project UserPrincipalName, UserAgent, Browser, IPAddress = LatestIP, TimeGenerated
//////////////////////////////////////////////////////////////////////////////

5. Advanced: Correlating Sign-ins with Defender Data
If you use Microsoft Defender for Endpoint, you can join the sign-in data with the actual machine health logs. This is the most "computationally logical" way to get a 360-degree view.

let n = 30;
let SigninData = SigninLogs
| where TimeGenerated > ago(n * 1d)
| extend AadDeviceId = tostring(DeviceDetail.deviceId)
| where isnotempty(AadDeviceId);
DeviceInfo
| where TimeGenerated > ago(n * 1d)
| join kind=inner (SigninData) on $left.AadDeviceId == $right.AadDeviceId
| summarize 
    LastLogin = max(TimeGenerated), 
    OS = any(OSPlatform), 
    RiskLevel = any(MachineComplianceStatus) 
    by DeviceName, AadDeviceId, UserPrincipalName
	
//////////////////////////////////////////////////////////////////////////////

More context to add to our engineering - 
Important Context
Log Retention: By default, Azure AD stores logs for 30 days (P1/P2 licenses). If you need to go back further, these queries must be run against a Log Analytics Workspace where logs are being streamed.

The "DeviceDetail" Object: Note that the DeviceDetail column is dynamic; you must use tostring() or extend to make the data sortable and readable.

