var helpcontent = new Array(26);
var help_enable = '<% nvram_get_x("", "help_enable"); %>';

helpcontent[0] = new Array("");
helpcontent[1] = new Array("");
helpcontent[2] = new Array("");
helpcontent[3] = new Array("");

helpcontent[4] = new Array("",
				"<#LANHostConfig_IPRouters_itemdesc#>",
				"<#LANHostConfig_SubnetMask_itemdesc#>",
				"<#LANHostConfig_x_Gateway_itemdesc#>",
				"<#LAN_STP_itemdesc#>");
helpcontent[5] = new Array("",
				"<#LANHostConfig_DHCPServerConfigurable_itemdesc#>",
				"<#LANHostConfig_DomainName_itemdesc#> <#LANHostConfig_x_DDNS_alarm_hostname#> <#LANHostConfig_DomainName_itemdesc2#>",
				"<#LANHostConfig_MinAddress_itemdesc#>",
				"<#LANHostConfig_MaxAddress_itemdesc#>",
				"<#LANHostConfig_LeaseTime_itemdesc#>",
				"<#LANHostConfig_x_LGateway_itemdesc#>",
				"<#LANHostConfig_x_LDNSServer1_itemdesc#>",
				"<#LANHostConfig_x_LDNSServer1_itemdesc#>",
				"<#LANHostConfig_x_LDNSServer1_itemdesc#>",
				"<#LANHostConfig_x_LDNSServer6_itemdesc#>",
				"<#LANHostConfig_x_WINSServer_itemdesc#>",
				"<#LANHostConfig_ForceDNS_itemdesc#>",
				"<#LANHostConfig_DHCPFilterAAAA_itemdesc#>",
				"<#LANHostConfig_DHCPAllservers_itemdesc#>",
				"<#LANHostConfig_DHCPStrictorder_itemdesc#>",
				"<#LANHostConfig_DHCPStopDNSRebind_itemdesc#>",
				"<#LANHostConfig_DHCPProxyDNSSEC_itemdesc#>",
				"<#LANHostConfig_ManualDHCPEnable_itemdesc#>",
				"<#LANHostConfig_ManualARP_itemdesc#>");
helpcontent[6] = new Array("",
				"<#RHELP_desc4#>",
				"<#RHELP_desc5#>",
				"<#RHELP_desc6#>",
				"<#RHELP_desc7#>",
				"<#RHELP_desc8#>",
				"<#RHELP_desc9#>",
				"<#RouterConfig_GWMulticast_Multicast_all_itemdesc#>",
				"<#RouterConfig_GWMulticast_Multicast_all_itemdesc#>",
				"<#RouterConfig_GWMulticast_Multicast_all_itemdesc#>",
				"<#RouterConfig_GWMulticast_Multicast_all_itemdesc#>");
//WAN
helpcontent[7] = new Array("",
				"<#IPConnection_ExternalIPAddress_itemdesc#>",
				"<#IPConnection_x_ExternalSubnetMask_itemdesc#>",
				"<#IPConnection_x_ExternalGateway_itemdesc#>",
				"<#PPPConnection_UserName_itemdesc#>",
				"<#PPPConnection_Password_itemdesc#>",
				"<#PPPConnection_IdleDisconnectTime_itemdesc#>",
				"<#PPPConnection_x_PPPoEMTU_itemdesc#>",
				"<#PPPConnection_x_PPPoEMRU_itemdesc#>",
				"<#PPPConnection_x_ServiceName_itemdesc#>",
				"<#PPPConnection_x_AccessConcentrator_itemdesc#>",
				"<#PPPConnection_x_PPPoERelay_itemdesc#>",
				"<#IPConnection_x_DNSServerEnable_itemdesc#>",
				"<#IPConnection_x_DNSServer1_itemdesc#>",
				"<#IPConnection_x_DNSServer1_itemdesc#>",
				"<#IPConnection_x_DNSServer1_itemdesc#>",
				"<#BOP_isp_host_desc#>",
				"<#PPPConnection_x_MacAddressForISP_itemdesc#>",
				"<#PPPConnection_x_PPTPOptions_itemdesc#>",
				"<#PPPConnection_x_AdditionalOptions_itemdesc#>",
				"<#BOP_isp_heart_desc#>",
				"<#IPConnection_BattleNet_itemdesc#>",
				"<#Layer3Forwarding_x_STB_itemdesc#>",
				"<#hwnat_desc#>",
				"<#hwnat_desc#>",
				"<#vpn_passthrough_desc#>",
				"<#vpn_passthrough_desc#>",
				"<#vpn_passthrough_desc#>");
//Firewall
helpcontent[8] = new Array("",
				"<#FirewallConfig_WanLanLog_itemdesc#>",
				"<#FirewallConfig_x_WanWebEnable_itemdesc#>",
				"<#FirewallConfig_x_WanWebPort_itemdesc#>",
				"<#FirewallConfig_x_WanLPREnable_itemdesc#>",
				"<#FirewallConfig_x_WanPingEnable_itemdesc#>",
				"<#FirewallConfig_FirewallEnable_itemdesc#>",
				"<#FirewallConfig_DoSEnable_itemdesc#>",
				"<#FirewallConfig_DoSEnable_itemdesc#>");
helpcontent[9] = new Array("",
				"<#FirewallConfig_URLActiveDate_itemdesc#>",
				"<#FirewallConfig_URLActiveTime_itemdesc#>");
helpcontent[10] = new Array("",
				"<#FirewallConfig_LanWanActiveDate_itemdesc#>",
				"<#FirewallConfig_LanWanActiveTime_itemdesc#>",
				"<#FirewallConfig_LanWanDefaultAct_itemdesc#>",
				"<#FirewallConfig_LanWanICMP_itemdesc#>",
				"<#FirewallConfig_LanWanFirewallEnable_itemdesc#>");
//Administration
helpcontent[11] = new Array("",
				"<#LANHostConfig_x_ServerLogEnable_itemdesc#>",
				"<#LANHostConfig_x_TimeZone_itemdesc#>",
				"<#LANHostConfig_x_NTPServer_itemdesc#>",
				"<#LANHostConfig_x_Password_itemdesc#>");
//Log
helpcontent[12] = new Array("",
				"<#General_x_SystemUpTime_itemdesc#>",
				"<#PrinterStatus_x_PrinterModel_itemdesc#>",
				"<#PrinterStatus_x_PrinterStatus_itemdesc#>",
				"<#PrinterStatus_x_PrinterUser_itemdesc#>");
//WPS
helpcontent[13] = new Array("",
				"<#WLANConfig11b_x_WPS_itemdesc#>",
				"<#WLANConfig11b_x_WPSMode_itemdesc#>",
				"<#WLANConfig11b_x_WPSPIN_itemdesc#>",
				"<#WLANConfig11b_x_DevicePIN_itemdesc#>",
				"<#WLANConfig11b_x_WPSband_itemdesc#>");
//UPnP
helpcontent[14] = new Array("",
				"<#UPnPMediaServer_Help#>");
//AiDisk Wizard
helpcontent[15] = new Array("",
				"<#AiDisk_moreconfig#>",
				"<#AiDisk_Step1_help#><p><a href='../Advanced_AiDisk_ftp.asp' target='_parent' hidefocus='true'><#MoreConfig#></a></p><!--span style='color:#CC0000'><#AiDisk_Step1_help2#></span-->",
				"<#AiDisk_Step2_help#>",
				"<#AiDisk_Step3_help#>");
//EzQoS
helpcontent[16] = new Array("",
				"<#EZQoSDesc1#><br><#EZQoSDesc2#> <a href='/Advanced_QOSUserSpec_Content.asp'><#BM_title_User#></a>");
//Others in the USB application
helpcontent[17] = new Array("",
				"<#JS_storageMLU#>",
				"<#JS_storageright#>",
				"<#Help_of_Workgroup#>",
				"<#JS_basiconfig1#>",
				"<#JS_basiconfig3#>",
				"<#JS_basiconfig8#>",
				"<#ShareNode_Seeding_itemdesc#>",
				"<#ShareNode_MaxUpload_itemdesc#>",
				"<#BasicConfig_USBStorageWhiteist_itemdesc#>",
				"<#ShareNode_FTPLANG_itemdesc#>",
				"<#StorageTorrent_itemdesc#>",
				"<#StorageAria_itemdesc#>");

// MAC filter
helpcontent[18] = new Array("",
				"<#FirewallConfig_MFMethod_itemdesc#>",
				"<#Port_format#>",
				"<#IP_format#>");
// Setting
helpcontent[19] = new Array("",
				"<#Setting_factorydefault_itemdesc#>",
				"<#Setting_save_itemdesc#>",
				"<#Setting_upload_itemdesc#>",
				"<#Storage_upload_itemdesc#>");
// QoS
helpcontent[20] = new Array("",
				"<#BM_measured_uplink_speed_desc#>",
				"<#BM_manual_uplink_speed_desc#>");
// HSDPA
helpcontent[21] = new Array("",
				"<#HSDPAConfig_hsdpa_mode_itemdesc#>",
				"<#HSDPAConfig_pin_code_itemdesc#>",
				"<#HSDPAConfig_private_apn_itemdesc#>",
				"<#HSDPAConfig_MTU_itemdesc#>",
				"<#IPConnection_x_DNSServerEnable_itemdesc#>",
				"<#IPConnection_x_DNSServer1_itemdesc#>",
				"<#IPConnection_x_DNSServer1_itemdesc#>",
				"<#IPConnection_x_DNSServer1_itemdesc#>",
				"<#HSDPAConfig_isp_itemdesc#>",
				"<#HSDPAConfig_country_itemdesc#>",
				"<#HSDPAConfig_dialnum_itemdesc#>",
				"<#HSDPAConfig_username_itemdesc#>",
				"<#HSDPAConfig_password_itemdesc#>");

helpcontent[22] = new Array("",
				"<#OP_GW_desc1#>",
				"<#OP_GW_desc1#>",
				"<#OP_AP_desc1#>");
// Tweaks
helpcontent[23] = new Array("",
				"<#TweaksWdg_desc#>",
				"<#Adm_Svc_vlmcsd_desc#>",
				"<#Adm_Svc_iperf3_desc#>",
				"<#Adm_Svc_ttyd_desc#>",
				"<#Adm_System_wan_policy_desc#>");

// DDNS
helpcontent[24] = new Array("",
				"<#LANHostConfig_x_DDNSUserName_itemdesc#>",
				"<#LANHostConfig_x_DDNSPassword_itemdesc#>",
				"<#LANHostConfig_x_DDNSHostNames_itemdesc#>",
				"<#LANHostConfig_x_DDNSWildcard_itemdesc#>",
				"<#LANHostConfig_x_DDNSStatus_itemdesc#>");

// SmartDNS
helpcontent[25] = new Array("",
    "选【无】：SmartDNS 只监听自己端口；选【作为 dnsmasq 的上游服务器】：dnsmasq 把查询转发给 SmartDNS；选【重定向 53 端口到 SmartDNS】：iptables 劫持 53 到 SmartDNS。注意：端口为 53 时，后两者无效，会自动改为【无】。",
    "测速方式，可选 ping、tcp:端口、tcp-syn:端口、none，多个用逗号分隔。写入默认组，对所有未单独指定测速的域名生效。",
    "支持单个、范围、逗号分隔，如 65 28、65-68。",
    "缓存快过期时提前查询，加速域名响应。",
    "有请求时先回应过期记录，同时后台查询新结果，避免等待。",
    "用过期数据回复时使用的 TTL 值，单位秒。",
    "off=关闭；fatal=致命错误；error=错误；warn=警告；notice=重要通知；info=常规信息；debug=调试详情。级别递增，日志逐级增多。",
    "读取 dnsmasq 或 odhcpd 的租约文件解析本地主机名。",
    "故障时生成 coredump，最大 4 MiB，重启后清除",
    "输入域名：该域名（含子域）的解析结果写入名为 smartdns 的 ipset 集合；输入 IP：直接把该 IP 加入集合。",
    "使用指定服务器组查询，比如 office、home。可用于单独解析 gfwlist，如果不需要配合 SS 解析 gfwlist，可以不填。",
    "白名单：只接受指定范围的 IP；黑名单：丢弃指定范围的 IP。",
    "开启后本监听口跳过 ipset 写入（域名解析结果不加入集合），此时【设置 ipset 超时】对本监听口无效。默认关闭。",
    "开启后此监听口不应用 address 规则（不再强制域名返回指定 IP）。默认关闭，对当前监听口，该规则生效。",
    "开启后此监听口不应用 nameserver 规则（不再指定域名使用哪个上游组）。默认关闭，对当前监听口，该规则生效。",
    "开启后此监听口不应用 SOA (#) 规则（不再屏蔽指定域名）。默认关闭，对当前监听口，该规则生效。",
    "过期缓存最长可用时长，单位秒。0 表示不限时。",
    "缓存定期写入持久化文件的间隔，单位秒。0 表示禁用周期持久化。需开启【是否持久化缓存】。",
    "启用后把 chnroute.txt 的中国 IP 段设为全局白名单，解析结果只接受其中的 IP，其余丢弃。需 chnroute.txt 存在。",
    "启用后把 chnroute.txt 的中国 IP 段设为全局黑名单，解析结果中属于其中的 IP 会被丢弃。需 chnroute.txt 存在。");


function openTooltip(obj, hint_array_id, hint_show_id)
{
	if (help_enable == "0" && hint_show_id > 0)
		return;

	if(hint_array_id >= helpcontent.length)
		return;

	if(hint_array_id == 14
	    || hint_array_id == 15
	    || hint_array_id == 16
	    || hint_array_id == 20)
		return;

	if(hint_show_id >= helpcontent[hint_array_id].length)
		return;

	$j(obj).attr('data-original-title', obj.innerHTML).attr('data-content', helpcontent[hint_array_id][hint_show_id]);
	$j(obj).popover('show');
}

function openHint(hint_array_id, hint_show_id){
	if (help_enable == "0" && hint_show_id > 0)
		return;

	$('hintofPM').style.display = "";

	showtext($('helpname'), "<#CTL_help#>");

	if($("statusframe")){
		$("statusframe").src = "";
		$("statusframe").style.display = "none";
	}

	$('hint_body').style.display = "";
	$("statusframe").style.display = "none";

	showtext($('helpname'), "<#CTL_help#>");
	showtext($('hint_body'), helpcontent[hint_array_id][hint_show_id]);
}

function closeHint(){
	$('hintofPM').style.display = "none";
}
