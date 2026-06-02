using System.ComponentModel;
using System.Globalization;

namespace PreStage.Core.Localization;

public static class L10n
{
    private static bool _currentIsChinese;

    public static string Tr(string key)
    {
        if (_currentIsChinese && ChineseStrings.TryGetValue(key, out var zh))
            return zh;
        return key;
    }

    public static void SetLanguage(string lang)
    {
        _currentIsChinese = lang?.StartsWith("zh", StringComparison.OrdinalIgnoreCase) == true;
    }

    private static readonly Dictionary<string, string> ChineseStrings = new()
    {
        ["Unmarked"] = "未标记",
        ["Pick"] = "入选",
        ["Reject"] = "淘汰",
        ["Red"] = "红色",
        ["Yellow"] = "黄色",
        ["Green"] = "绿色",
        ["Blue"] = "蓝色",
        ["Purple"] = "紫色",
        ["Name"] = "文件名",
        ["Kind"] = "类型",
        ["Date Added"] = "添加日期",
        ["Date Modified"] = "修改日期",
        ["Date Created"] = "创建日期",
        ["Last Opened"] = "上次打开",
        ["Size"] = "大小",
        ["Grid"] = "网格",
        ["List"] = "列表",
        ["Gallery"] = "画廊",
        ["Grid View"] = "网格视图",
        ["List View"] = "列表视图",
        ["Gallery View"] = "画廊视图",
        ["Ascending"] = "升序",
        ["Descending"] = "降序",
        ["All Supported Files"] = "所有支持文件",
        ["RAW Files Only"] = "仅 RAW 文件",
        ["Auto Rename"] = "自动重命名",
        ["Skip Existing"] = "跳过已存在",
        ["Overwrite"] = "覆盖",
        ["Size Only"] = "仅大小",
        ["SHA-256 Hash"] = "SHA-256 哈希",
        ["Capture Date"] = "拍摄日期",
        ["Preserve Structure"] = "保留目录结构",
        ["Camera Model"] = "相机型号",
        ["Rating"] = "评分",
        ["Rule of Thirds"] = "三分法",
        ["Center Lines"] = "中心线",
        ["Diagonals"] = "对角线",
        ["Golden Ratio"] = "黄金比例",
        ["Hidden"] = "隐藏",
        ["Original"] = "原始",
        ["Mask"] = "遮幅",
        ["Frame"] = "框线",
        ["Floating"] = "浮动",
        ["Inspector"] = "检查器",
        ["Follow System"] = "跟随系统",
        ["Light"] = "浅色",
        ["Dark"] = "深色",
        ["System"] = "系统",
        ["Black"] = "黑色",
        ["White"] = "白色",
        ["Dark Gray"] = "深灰",
        ["Middle Gray"] = "中灰",
        ["Light Gray"] = "浅灰",
        ["None"] = "无",
        ["Small"] = "小",
        ["Medium"] = "中",
        ["Large"] = "大",
        ["Off"] = "关闭",
        ["Notify Only"] = "仅通知",
        ["Select DCIM"] = "选择 DCIM",
        ["Select DCIM and Scan"] = "选择 DCIM 并扫描",
        ["RGB + Luminance"] = "RGB + 亮度",
        ["RGB Only"] = "仅 RGB",
        ["Luminance Only"] = "仅亮度",
        ["Red Channel"] = "红色通道",
        ["Green Channel"] = "绿色通道",
        ["Blue Channel"] = "蓝色通道",
        ["Automatic"] = "自动",
        ["Landscape"] = "横向",
        ["Portrait"] = "纵向",
        ["Gray"] = "灰色",
        ["Accent"] = "强调色",
    };
}
