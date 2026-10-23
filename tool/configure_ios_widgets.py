"""维护 Flutter Runner 内的原生 WidgetKit target；只编辑工程，不执行编译。"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
project = root / 'ios/Runner.xcodeproj/project.pbxproj'
text = project.read_text()
if 'C10000000000000000000001 /* ClockWidgets */' in text:
    print('WidgetKit target already configured')
    raise SystemExit(0)


def section(name, content):
    global text
    marker = f'/* End {name} section */'
    assert marker in text, name
    text = text.replace(marker, content + '\n' + marker, 1)


section('PBXBuildFile', '''
        C10000000000000000000011 /* ClockWidgets.swift in Sources */ = {isa = PBXBuildFile; fileRef = C10000000000000000000021; };
        C10000000000000000000012 /* MechanicalWidgetFace.swift in Sources */ = {isa = PBXBuildFile; fileRef = C10000000000000000000022; };
        C10000000000000000000013 /* ClockWeatherClient.swift in Sources */ = {isa = PBXBuildFile; fileRef = C10000000000000000000023; };
        C10000000000000000000014 /* ClockWidgetData.swift in Widget Sources */ = {isa = PBXBuildFile; fileRef = C10000000000000000000024; };
        C10000000000000000000015 /* ClockWidgetData.swift in App Sources */ = {isa = PBXBuildFile; fileRef = C10000000000000000000024; };
        C10000000000000000000016 /* ClockWidgets.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = C10000000000000000000025; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
        C10000000000000000000017 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = C10000000000000000000026; };
''')
section('PBXContainerItemProxy', '''
        C10000000000000000000030 = {isa = PBXContainerItemProxy; containerPortal = 97C146E61CF9000F007C117D; proxyType = 1; remoteGlobalIDString = C10000000000000000000001; remoteInfo = ClockWidgets; };
''')
section('PBXCopyFilesBuildPhase', '''
        C10000000000000000000031 /* Embed App Extensions */ = {isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = (C10000000000000000000016, ); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0; };
''')
section('PBXFileReference', '''
        C10000000000000000000021 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ClockWidgets.swift; sourceTree = "<group>"; };
        C10000000000000000000022 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MechanicalWidgetFace.swift; sourceTree = "<group>"; };
        C10000000000000000000023 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ClockWeatherClient.swift; sourceTree = "<group>"; };
        C10000000000000000000024 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ClockWidgetData.swift; sourceTree = "<group>"; };
        C10000000000000000000025 = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = ClockWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; };
        C10000000000000000000026 = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
        C10000000000000000000027 = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
        C10000000000000000000028 = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = ClockWidgets.entitlements; sourceTree = "<group>"; };
''')
section('PBXGroup', '''
        C10000000000000000000040 = {isa = PBXGroup; children = (C10000000000000000000021, C10000000000000000000022, C10000000000000000000023, C10000000000000000000026, C10000000000000000000027, C10000000000000000000028, ); path = ClockWidgets; sourceTree = "<group>"; };
        C10000000000000000000041 = {isa = PBXGroup; children = (C10000000000000000000024, ); path = Shared; sourceTree = "<group>"; };
''')
section('PBXNativeTarget', '''
        C10000000000000000000001 /* ClockWidgets */ = {
            isa = PBXNativeTarget;
            buildConfigurationList = C10000000000000000000050;
            buildPhases = (C10000000000000000000032, C10000000000000000000033, C10000000000000000000034, );
            buildRules = (); dependencies = (); name = ClockWidgets; productName = ClockWidgets;
            productReference = C10000000000000000000025; productType = "com.apple.product-type.app-extension";
        };
''')
section('PBXSourcesBuildPhase', '''
        C10000000000000000000032 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (C10000000000000000000011, C10000000000000000000012, C10000000000000000000013, C10000000000000000000014, ); runOnlyForDeploymentPostprocessing = 0; };
''')
section('PBXFrameworksBuildPhase', '''
        C10000000000000000000033 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
''')
section('PBXResourcesBuildPhase', '''
        C10000000000000000000034 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (C10000000000000000000017, ); runOnlyForDeploymentPostprocessing = 0; };
''')
section('PBXTargetDependency', '''
        C10000000000000000000035 = {isa = PBXTargetDependency; target = C10000000000000000000001; targetProxy = C10000000000000000000030; };
''')
configurations = []
for index, name in enumerate(('Debug', 'Release', 'Profile')):
    identifier = f'C1000000000000000000006{index}'
    configurations.append(identifier)
    section('XCBuildConfiguration', f'''
        {identifier} /* {name} Widget */ = {{
            isa = XCBuildConfiguration;
            baseConfigurationReference = 9740EEB31CF90195004384FC;
            buildSettings = {{
                APPLICATION_EXTENSION_API_ONLY = YES;
                CODE_SIGN_ENTITLEMENTS = ClockWidgets/ClockWidgets.entitlements;
                CODE_SIGN_STYLE = Automatic;
                CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";
                ENABLE_USER_SCRIPT_SANDBOXING = NO;
                GENERATE_INFOPLIST_FILE = NO;
                INFOPLIST_FILE = ClockWidgets/Info.plist;
                IPHONEOS_DEPLOYMENT_TARGET = 18.0;
                LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks", );
                PRODUCT_BUNDLE_IDENTIFIER = com.xiongjian.widget.ClockWidgets;
                PRODUCT_NAME = "$(TARGET_NAME)";
                SKIP_INSTALL = YES;
                SWIFT_VERSION = 5.0;
                TARGETED_DEVICE_FAMILY = "1,2";
                VERSIONING_SYSTEM = "apple-generic";
            }};
            name = {name};
        }};
''')
section('XCConfigurationList', f'''
        C10000000000000000000050 = {{isa = XCConfigurationList; buildConfigurations = ({', '.join(configurations)}, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
''')
# 新扩展在 Flutter Build/Embed 之前完成复制，遵循 Flutter 扩展的构建顺序。
needle = 'buildPhases = (\n\t\t\t\t9740EEB61CF901F6004384FC'
assert needle in text
text = text.replace(needle, 'buildPhases = (\n                C10000000000000000000031 /* Embed App Extensions */,\n\t\t\t\t9740EEB61CF901F6004384FC', 1)
start = text.index('97C146ED1CF9000F007C117D /* Runner */ = {')
end = text.index('/* End PBXNativeTarget section */', start)
target = text[start:end].replace('dependencies = (\n\t\t\t);', 'dependencies = (C10000000000000000000035, );', 1)
text = text[:start] + target + text[end:]
text = text.replace('97C146E51CF9000F007C117D = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (',
                    '97C146E51CF9000F007C117D = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (C10000000000000000000040, C10000000000000000000041,', 1)
text = text.replace('97C146EE1CF9000F007C117D /* Runner.app */,', '97C146EE1CF9000F007C117D /* Runner.app */, C10000000000000000000025,', 1)
text = text.replace('targets = (\n', 'targets = (C10000000000000000000001,\n', 1)
text = text.replace('74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,',
                    '74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */, C10000000000000000000015,', 1)
text = text.replace('INFOPLIST_FILE = Runner/Info.plist;', 'INFOPLIST_FILE = Runner/Info.plist;\n                CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;')
text = text.replace('TargetAttributes = {', '''TargetAttributes = {
                    C10000000000000000000001 = {CreatedOnToolsVersion = 16.0; SystemCapabilities = {com.apple.ApplicationGroups.iOS = {enabled = 1; }; }; };''', 1)
project.write_text(text)
print('Added native WidgetKit extension, dependency, shared sources, embed phase and entitlements')
