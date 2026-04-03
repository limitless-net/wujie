// ignore_for_file: avoid_print
//
// branding.dart — 全自动品牌定制脚本
//
// 用法：dart run branding.dart
//
// 从 assets/config/xboard.config.yaml 读取 branding 配置，
// 自动替换所有平台的应用名称和图标文件，无需手动修改任何代码。
//

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

// ============================================================
// 主入口
// ============================================================
void main(List<String> args) async {
  print('');
  print('╔══════════════════════════════════════════════╗');
  print('║        Xboard-Mihomo 品牌定制工具            ║');
  print('╚══════════════════════════════════════════════╝');
  print('');

  final projectRoot = Directory.current.path;
  final configPath =
      p.join(projectRoot, 'assets', 'config', 'xboard.config.yaml');

  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    print('❌ 找不到配置文件: $configPath');
    exit(1);
  }

  final yamlStr = configFile.readAsStringSync();
  final doc = loadYaml(yamlStr);
  final branding = doc?['xboard']?['branding'];

  if (branding == null) {
    print('❌ 配置文件中未找到 xboard.branding 节');
    exit(1);
  }

  final appName = branding['app_name']?.toString() ?? 'Flclash';
  final appNameEn = branding['app_name_en']?.toString() ?? appName;
  final packageId = branding['package_id']?.toString() ?? 'com.follow.clash';
  final iconDir = branding['icon_dir']?.toString() ?? 'assets/branding';
  final version = branding['version']?.toString();

  print('📋 品牌配置：');
  print('   应用名称:  $appName');
  print('   英文名称:  $appNameEn');
  print('   包标识符:  $packageId');
  print('   图标目录:  $iconDir');
  if (version != null) {
    print('   版本号:    $version');
  }
  print('');

  // 执行品牌替换
  _applyAppName(projectRoot, appName, appNameEn, packageId);
  _applyIcons(projectRoot, iconDir);
  if (version != null) {
    _applyVersion(projectRoot, version);
  }

  print('');
  print('✅ 品牌定制完成！现在可以正常打包。');
  print('');
}

// ============================================================
// 应用名称替换
// ============================================================
void _applyAppName(String root, String appName, String appNameEn, String packageId) {
  print('🔧 正在替换应用名称...');

  int count = 0;

  // 1. distribute_options.yaml — 必须用英文名，RPM/DEB 包名不允许非 ASCII
  count += _replaceInFile(
    p.join(root, 'distribute_options.yaml'),
    RegExp(r"app_name:\s*'[^']*'"),
    "app_name: '$appNameEn'",
    'distribute_options.yaml',
  );

  // 2. Windows: main.cpp — 窗口标题 (使用 Unicode 转义避免编码问题)
  final escapedAppName = _toCppUnicodeEscape(appName);
  count += _replaceInFile(
    p.join(root, 'windows', 'runner', 'main.cpp'),
    RegExp(r'window\.Create\(L"[^"]*"'),
    'window.Create(L"$escapedAppName"',
    'windows/runner/main.cpp',
  );

  // 3. Windows: Runner.rc — 产品信息 (写入后确保 UTF-8 BOM)
  final rcPath = p.join(root, 'windows', 'runner', 'Runner.rc');
  count += _replaceInFile(
    rcPath,
    RegExp(r'VALUE "FileDescription",\s*"[^"]*"'),
    'VALUE "FileDescription", "$appName"',
    'Runner.rc (FileDescription)',
  );
  count += _replaceInFile(
    rcPath,
    RegExp(r'VALUE "InternalName",\s*"[^"]*"'),
    'VALUE "InternalName", "$appName"',
    'Runner.rc (InternalName)',
  );
  count += _replaceInFile(
    rcPath,
    RegExp(r'VALUE "OriginalFilename",\s*"[^"]*"'),
    'VALUE "OriginalFilename", "$appName.exe"',
    'Runner.rc (OriginalFilename)',
  );
  count += _replaceInFile(
    rcPath,
    RegExp(r'VALUE "ProductName",\s*"[^"]*"'),
    'VALUE "ProductName", "$appName"',
    'Runner.rc (ProductName)',
  );
  // 确保 Runner.rc 带 UTF-8 BOM，否则 MSVC 将中文按 GBK 编译导致乱码
  _ensureUtf8Bom(rcPath);

  // 3b. Windows: CMakeLists.txt — 项目名和可执行文件名
  final winCmakePath = p.join(root, 'windows', 'CMakeLists.txt');
  count += _replaceInFile(
    winCmakePath,
    RegExp(r'project\([\w\-]+\s+LANGUAGES'),
    'project($appNameEn LANGUAGES',
    'windows/CMakeLists.txt (project)',
  );
  count += _replaceInFile(
    winCmakePath,
    RegExp(r'set\(BINARY_NAME\s+"[^"]*"\)'),
    'set(BINARY_NAME "$appNameEn")',
    'windows/CMakeLists.txt (BINARY_NAME)',
  );

  // 3c. Windows: make_config.yaml — 安装器配置
  final makeConfigPath = p.join(root, 'windows', 'packaging', 'exe', 'make_config.yaml');
  count += _replaceInFile(
    makeConfigPath,
    RegExp(r'app_name:\s*\S+'),
    'app_name: $appName',
    'make_config.yaml (app_name)',
  );
  count += _replaceInFile(
    makeConfigPath,
    RegExp(r'display_name:\s*\S+'),
    'display_name: $appName',
    'make_config.yaml (display_name)',
  );
  count += _replaceInFile(
    makeConfigPath,
    RegExp(r'executable_name:\s*\S+'),
    'executable_name: $appNameEn.exe',
    'make_config.yaml (executable_name)',
  );
  count += _replaceInFile(
    makeConfigPath,
    RegExp(r'output_base_file_name:\s*\S+'),
    'output_base_file_name: $appNameEn.exe',
    'make_config.yaml (output_base_file_name)',
  );
  count += _replaceInFile(
    makeConfigPath,
    RegExp(r'publisher:\s*\S+'),
    'publisher: $appNameEn',
    'make_config.yaml (publisher)',
  );

  // 3d. Windows: inno_setup.iss — 进程名
  count += _replaceInFile(
    p.join(root, 'windows', 'packaging', 'exe', 'inno_setup.iss'),
    RegExp(r"Processes\s*:=\s*\['[^']*\.exe'"),
    "Processes := ['$appNameEn.exe'",
    'inno_setup.iss (process name)',
  );

  // 3e. lib/common/constant.dart — appNameEn
  count += _replaceInFile(
    p.join(root, 'lib', 'common', 'constant.dart'),
    RegExp(r'const appNameEn\s*=\s*"[^"]*"'),
    'const appNameEn = "$appNameEn"',
    'constant.dart (appNameEn)',
  );

  // 4. Android: AndroidManifest.xml — 应用名 (替换所有 label)
  count += _replaceInFileAll(
    p.join(root, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    RegExp(r'android:label="[^"]*"'),
    'android:label="$appName"',
    'AndroidManifest.xml (all labels)',
  );

  // 4b. Android: debug AndroidManifest.xml — 应用名
  final debugManifest = p.join(root, 'android', 'app', 'src', 'debug', 'AndroidManifest.xml');
  count += _replaceInFileAll(
    debugManifest,
    RegExp(r'android:label="[^"]*"'),
    'android:label="$appName Debug"',
    'debug/AndroidManifest.xml (all labels)',
  );

  // 5. Android: strings.xml
  count += _replaceInFile(
    p.join(root, 'android', 'app', 'src', 'main', 'res', 'values', 'strings.xml'),
    RegExp(r'<string name="fl_clash">[^<]*</string>'),
    '<string name="fl_clash">$appName</string>',
    'strings.xml',
  );

  // 6. Android: build.gradle.kts — 仅替换 applicationId
  //    注意: namespace 必须保持 com.follow.clash 与 Kotlin 源码包名一致，
  //    否则 AndroidManifest 中的相对类名(.FlClashApplication 等)无法解析导致闪退
  final gradlePath =
      p.join(root, 'android', 'app', 'build.gradle.kts');
  count += _replaceInFile(
    gradlePath,
    RegExp(r'applicationId\s*=\s*"[^"]*"'),
    'applicationId = "$packageId"',
    'build.gradle.kts (applicationId)',
  );

  // 7. Linux: CMakeLists.txt
  // Linux CMake 的 BINARY_NAME 必须用英文，中文会导致 CMake 报错
  final cmakePath = p.join(root, 'linux', 'CMakeLists.txt');
  count += _replaceInFile(
    cmakePath,
    RegExp(r'set\(BINARY_NAME\s+"[^"]*"\)'),
    'set(BINARY_NAME "$appNameEn")',
    'CMakeLists.txt (BINARY_NAME)',
  );
  count += _replaceInFile(
    cmakePath,
    RegExp(r'set\(APPLICATION_ID\s+"[^"]*"\)'),
    'set(APPLICATION_ID "$packageId")',
    'CMakeLists.txt (APPLICATION_ID)',
  );

  // 8. Linux: my_application.cc — 窗口标题
  final myAppPath = p.join(root, 'linux', 'my_application.cc');
  count += _replaceInFile(
    myAppPath,
    RegExp(r'gtk_header_bar_set_title\(header_bar,\s*"[^"]*"\)'),
    'gtk_header_bar_set_title(header_bar, "$appName")',
    'my_application.cc (header_bar)',
  );
  count += _replaceInFile(
    myAppPath,
    RegExp(r'gtk_window_set_title\(window,\s*"[^"]*"\)'),
    'gtk_window_set_title(window, "$appName")',
    'my_application.cc (window_title)',
  );

  // 9. Linux 打包配置
  for (final pkg in ['deb', 'rpm', 'appimage']) {
    final makeConfigPath =
        p.join(root, 'linux', 'packaging', pkg, 'make_config.yaml');
    count += _replaceInFileAll(
      makeConfigPath,
      RegExp(r'display_name:\s*\S+'),
      'display_name: $appName',
      '$pkg/make_config.yaml (display_name)',
    );
    // package_name (deb/rpm only) — 必须用小写英文名，dpkg 不允许非 ASCII
    count += _replaceInFileAll(
      makeConfigPath,
      RegExp(r'package_name:\s*\S+'),
      'package_name: ${appNameEn.toLowerCase()}',
      '$pkg/make_config.yaml (package_name)',
    );
    count += _replaceInFileAll(
      makeConfigPath,
      RegExp(r'generic_name:\s*\S+'),
      'generic_name: $appName',
      '$pkg/make_config.yaml (generic_name)',
    );
  }

  // 10. macOS: AppInfo.xcconfig
  final xcPath =
      p.join(root, 'macos', 'Runner', 'Configs', 'AppInfo.xcconfig');
  count += _replaceInFile(
    xcPath,
    RegExp(r'PRODUCT_NAME\s*=\s*.*'),
    'PRODUCT_NAME = $appName',
    'AppInfo.xcconfig (PRODUCT_NAME)',
  );
  count += _replaceInFile(
    xcPath,
    RegExp(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*.*'),
    'PRODUCT_BUNDLE_IDENTIFIER = $packageId',
    'AppInfo.xcconfig (PRODUCT_BUNDLE_IDENTIFIER)',
  );

  // 10b. macOS: DMG make_config.yaml — 更新 title 和 app 路径
  final dmgConfigPath =
      p.join(root, 'macos', 'packaging', 'dmg', 'make_config.yaml');
  count += _replaceInFile(
    dmgConfigPath,
    RegExp(r'title:\s*\S+'),
    'title: $appName',
    'dmg/make_config.yaml (title)',
  );
  count += _replaceInFile(
    dmgConfigPath,
    RegExp(r'path:\s*\S+\.app'),
    'path: $appName.app',
    'dmg/make_config.yaml (path)',
  );

  // 11. setup.dart — Build.appName
  count += _replaceInFile(
    p.join(root, 'setup.dart'),
    RegExp(r'''static String get appName\s*=>\s*["'][^"']*["']'''),
    'static String get appName => "$appName"',
    'setup.dart (appName)',
  );

  // 12. lib/common/constant.dart — appName
  count += _replaceInFile(
    p.join(root, 'lib', 'common', 'constant.dart'),
    RegExp(r'const appName\s*=\s*"[^"]*"'),
    'const appName = "$appName"',
    'constant.dart (appName)',
  );

  print('   ✅ 共替换 $count 处名称/包名');
}

// ============================================================
// 版本号替换
// ============================================================
void _applyVersion(String root, String version) {
  print('📦 正在更新版本号...');

  int count = 0;

  // 1. pubspec.yaml — 主版本定义
  count += _replaceInFile(
    p.join(root, 'pubspec.yaml'),
    RegExp(r'^version:\s*.+$', multiLine: true),
    'version: $version',
    'pubspec.yaml (version)',
  );

  // 2. Android: build.gradle.kts — versionName / versionCode
  final gradlePath = p.join(root, 'android', 'app', 'build.gradle.kts');
  // 提取 major.minor.patch 和 buildNumber
  final plusIndex = version.indexOf('+');
  final versionName = plusIndex > 0 ? version.substring(0, plusIndex) : version;
  final versionCode = plusIndex > 0 ? version.substring(plusIndex + 1) : null;

  if (versionCode != null) {
    count += _replaceInFile(
      gradlePath,
      RegExp(r'versionCode\s*=\s*\d+'),
      'versionCode = $versionCode',
      'build.gradle.kts (versionCode)',
    );
  }
  count += _replaceInFile(
    gradlePath,
    RegExp(r'versionName\s*=\s*"[^"]*"'),
    'versionName = "$versionName"',
    'build.gradle.kts (versionName)',
  );

  // 3. Windows: Runner.rc — 文件版本号
  final rcPath = p.join(root, 'windows', 'runner', 'Runner.rc');
  // 转换 2.6.1 → 2,6,1,0 格式（RC文件需要逗号分隔的四段版本号）
  final versionParts = versionName.split('.');
  while (versionParts.length < 4) {
    versionParts.add('0');
  }
  final rcVersion = versionParts.take(4).join(',');
  count += _replaceInFile(
    rcPath,
    RegExp(r'FILEVERSION\s+[\d,]+'),
    'FILEVERSION $rcVersion',
    'Runner.rc (FILEVERSION)',
  );
  count += _replaceInFile(
    rcPath,
    RegExp(r'PRODUCTVERSION\s+[\d,]+'),
    'PRODUCTVERSION $rcVersion',
    'Runner.rc (PRODUCTVERSION)',
  );
  count += _replaceInFile(
    rcPath,
    RegExp(r'VALUE "FileVersion",\s*"[^"]*"'),
    'VALUE "FileVersion", "$versionName"',
    'Runner.rc (FileVersion)',
  );
  count += _replaceInFile(
    rcPath,
    RegExp(r'VALUE "ProductVersion",\s*"[^"]*"'),
    'VALUE "ProductVersion", "$versionName"',
    'Runner.rc (ProductVersion)',
  );
  // 确保 Runner.rc 保持 UTF-8 BOM
  _ensureUtf8Bom(rcPath);

  // 4. macOS: AppInfo.xcconfig — MARKETING_VERSION
  count += _replaceInFile(
    p.join(root, 'macos', 'Runner', 'Configs', 'AppInfo.xcconfig'),
    RegExp(r'MARKETING_VERSION\s*=\s*.*'),
    'MARKETING_VERSION = $versionName',
    'AppInfo.xcconfig (MARKETING_VERSION)',
  );

  print('   ✅ 共更新 $count 处版本号');
}

// ============================================================
// 图标替换
// ============================================================
void _applyIcons(String root, String iconDirRel) {
  final iconDir = Directory(p.join(root, iconDirRel));
  if (!iconDir.existsSync()) {
    print('ℹ️  图标目录不存在 ($iconDirRel)，跳过图标替换');
    print('   如需更换图标，请创建该目录并放入 icon.png (1024x1024)');
    return;
  }

  print('🎨 正在替换图标...');
  int count = 0;

  final mainIcon = File(p.join(iconDir.path, 'icon.png'));
  final mainIco = File(p.join(iconDir.path, 'icon.ico'));

  if (!mainIcon.existsSync()) {
    print('   ⚠️  未找到 $iconDirRel/icon.png，跳过图标替换');
    return;
  }

  // ---- 通用图标 (assets/images/) ----
  count += _copyIcon(mainIcon.path, p.join(root, 'assets', 'images', 'icon.png'));

  if (mainIco.existsSync()) {
    count += _copyIcon(mainIco.path, p.join(root, 'assets', 'images', 'icon.ico'));
  }

  // 可选的托盘图标
  for (final variant in ['icon_white', 'icon_black', 'icon_connected', 'icon_disconnected']) {
    for (final ext in ['png', 'ico']) {
      final src = File(p.join(iconDir.path, '$variant.$ext'));
      if (src.existsSync()) {
        count += _copyIcon(src.path, p.join(root, 'assets', 'images', '$variant.$ext'));
      }
    }
  }

  // ---- Windows 图标 ----
  if (mainIco.existsSync()) {
    count += _copyIcon(
        mainIco.path, p.join(root, 'windows', 'runner', 'resources', 'app_icon.ico'));
  } else {
    // 如果没有 .ico，复制 .png 到 assets/images（Windows 资源文件引用 .ico，
    // 用户需要自行提供 .ico 或使用在线工具转换）
    print('   ⚠️  未提供 icon.ico，Windows 图标需要 .ico 格式');
    print('      请将 icon.png 转为 .ico 后放入 $iconDirRel/icon.ico');
  }

  // ---- macOS 图标 ----
  final macIconDir = p.join(
      root, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset');
  final macSizes = [16, 32, 64, 128, 256, 512, 1024];
  for (final size in macSizes) {
    final target = p.join(macIconDir, 'app_icon_$size.png');
    // 直接用原图覆盖，macOS 会自动缩放显示
    // 如果用户有精确尺寸的图标更好，但1024大图也能工作
    count += _copyIcon(mainIcon.path, target);
  }

  // ---- Android 图标 ----
  // Android webp 图标需要特殊处理，这里用 png 覆盖 foreground drawable
  // 主图标文件覆盖
  final androidResDir =
      p.join(root, 'android', 'app', 'src', 'main', 'res');
  final androidDpis = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  // 检查是否有预制的 Android 特定图标
  final androidIconDir = Directory(p.join(iconDir.path, 'android'));
  if (androidIconDir.existsSync()) {
    // 如果提供了 android/ 子目录，按分辨率精确替换
    for (final entry in androidDpis.entries) {
      for (final name in ['ic_launcher.webp', 'ic_launcher_round.webp', 'ic_launcher.png']) {
        final src =
            File(p.join(androidIconDir.path, entry.key, name));
        if (src.existsSync()) {
          count += _copyIcon(
              src.path, p.join(androidResDir, entry.key, name));
        }
      }
    }
  } else {
    print('   ℹ️  未提供 $iconDirRel/android/ 目录');
    print('      Android 图标需要 webp 格式的多分辨率文件');
    print('      建议使用 Android Studio Image Asset 工具从 icon.png 生成');
    print('      然后放入 $iconDirRel/android/mipmap-*/ 目录');
  }

  // ---- Android 自适应图标矢量文件 ----
  // 替换 drawable/ic_launcher_foreground.xml (前景)
  final fgSrc = File(p.join(iconDir.path, 'android', 'ic_launcher_foreground.xml'));
  if (fgSrc.existsSync()) {
    count += _copyIcon(
        fgSrc.path, p.join(androidResDir, 'drawable', 'ic_launcher_foreground.xml'));
  }

  // 替换 drawable/ic_launcher_background.xml (渐变背景)
  final bgSrc = File(p.join(iconDir.path, 'android', 'ic_launcher_background.xml'));
  if (bgSrc.existsSync()) {
    count += _copyIcon(
        bgSrc.path, p.join(androidResDir, 'drawable', 'ic_launcher_background.xml'));

    // 同时更新 mipmap-anydpi-v26 的 XML，把 @color/ 改为 @drawable/
    for (final xmlName in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
      final xmlPath = p.join(androidResDir, 'mipmap-anydpi-v26', xmlName);
      _replaceInFile(
        xmlPath,
        RegExp(r'android:drawable="@color/ic_launcher_background"'),
        'android:drawable="@drawable/ic_launcher_background"',
        'mipmap-anydpi-v26/$xmlName (background → drawable)',
      );
    }
  }

  // 替换 drawable/ic.xml (状态栏/通知栏小图标)
  final icSrc = File(p.join(iconDir.path, 'android', 'ic.xml'));
  if (icSrc.existsSync()) {
    count += _copyIcon(
        icSrc.path, p.join(androidResDir, 'drawable', 'ic.xml'));
  }

  // 替换 ic_launcher_background 颜色 (备用，用于非渐变背景)
  final bgColorSrc = File(p.join(iconDir.path, 'android', 'ic_launcher_background_color.xml'));
  if (bgColorSrc.existsSync()) {
    count += _copyIcon(
        bgColorSrc.path, p.join(androidResDir, 'values', 'ic_launcher_background.xml'));
  }

  print('   ✅ 共替换 $count 个图标文件');
}

// ============================================================
// 工具函数
// ============================================================

/// 替换文件中第一个匹配项，返回替换数量(0或1)
int _replaceInFile(String filePath, RegExp pattern, String replacement, String desc) {
  final file = File(filePath);
  if (!file.existsSync()) {
    // print('   ⏭  跳过 $desc (文件不存在)');
    return 0;
  }
  final content = file.readAsStringSync();
  if (!pattern.hasMatch(content)) {
    // print('   ⏭  跳过 $desc (未匹配)');
    return 0;
  }
  final newContent = content.replaceFirst(pattern, replacement);
  if (newContent != content) {
    file.writeAsStringSync(newContent);
    print('   ✏️  $desc');
    return 1;
  }
  return 0;
}

/// 替换文件中所有匹配项
int _replaceInFileAll(String filePath, RegExp pattern, String replacement, String desc) {
  final file = File(filePath);
  if (!file.existsSync()) return 0;
  final content = file.readAsStringSync();
  if (!pattern.hasMatch(content)) return 0;
  final newContent = content.replaceAll(pattern, replacement);
  if (newContent != content) {
    file.writeAsStringSync(newContent);
    print('   ✏️  $desc');
    return 1;
  }
  return 0;
}

/// 复制图标文件
int _copyIcon(String src, String dst) {
  final srcFile = File(src);
  if (!srcFile.existsSync()) return 0;

  final dstFile = File(dst);
  final dstDir = dstFile.parent;
  if (!dstDir.existsSync()) {
    dstDir.createSync(recursive: true);
  }

  srcFile.copySync(dst);
  final relDst = p.relative(dst);
  print('   📄 $relDst');
  return 1;
}

/// 将字符串转为 C++ wchar_t Unicode 转义 (\\uXXXX)
/// 仅转义非 ASCII 字符，ASCII 保持原样
String _toCppUnicodeEscape(String s) {
  final buf = StringBuffer();
  for (final codeUnit in s.codeUnits) {
    if (codeUnit > 127) {
      buf.write('\\u${codeUnit.toRadixString(16).padLeft(4, '0')}');
    } else {
      buf.writeCharCode(codeUnit);
    }
  }
  return buf.toString();
}

/// 确保文件以 UTF-8 BOM 开头 (EF BB BF)
/// 某些 Windows 编译器 (MSVC rc.exe) 需要 BOM 才能正确识别 UTF-8
void _ensureUtf8Bom(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  // 检查是否已有 BOM
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    return; // 已有 BOM
  }
  // 在头部插入 BOM
  final bomBytes = [0xEF, 0xBB, 0xBF, ...bytes];
  file.writeAsBytesSync(bomBytes);
  print('   🔤 添加 UTF-8 BOM: ${p.relative(filePath)}');
}
