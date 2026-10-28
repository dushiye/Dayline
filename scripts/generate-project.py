#!/usr/bin/env python3
"""Generate a dependency-free Xcode project from the checked-in Swift sources."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent.parent
project = root / 'Dayline.xcodeproj'
project.mkdir(exist_ok=True)
objects = []
def uid(value): return hashlib.sha256(value.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(str(value), ensure_ascii=False)
def obj(key, body): objects.append(f'\t\t{uid(key)} = {{ {body} }};')
def ids(values):
    if not values: return '()'
    return '(' + ', '.join(uid(x) for x in values) + ',)'
sources = [str(p.relative_to(root)) for p in sorted((root/'Sources'/'Dayline').rglob('*.swift'))]
tests = [str(p.relative_to(root)) for p in sorted((root/'Tests'/'DaylineTests').rglob('*.swift'))]
test_fixtures = [str(p.relative_to(root)) for p in sorted((root/'Tests'/'Fixtures').iterdir()) if p.is_file()]
ios_sources = [str(p.relative_to(root)) for p in sorted((root/'Sources'/'DaylineIOS').rglob('*.swift'))] if (root/'Sources'/'DaylineIOS').exists() else []
ios_tests = [str(p.relative_to(root)) for p in sorted((root/'Tests'/'DaylineIOSTests').rglob('*.swift'))] if (root/'Tests'/'DaylineIOSTests').exists() else []
ios_ui = [str(p.relative_to(root)) for p in sorted((root/'Tests'/'DaylineIOSUITests').rglob('*.swift'))] if (root/'Tests'/'DaylineIOSUITests').exists() else []
resources = ['Resources/Dayline.icns'] if (root/'Resources/Dayline.icns').exists() else []
ios_plist = ['Resources/iOS/Info.plist'] if (root/'Resources/iOS/Info.plist').exists() else []
for path in sources + tests + test_fixtures + ios_sources + ios_tests + ios_ui + resources + ['Resources/Info.plist', 'README.md'] + ios_plist:
    filetype = 'sourcecode.swift' if path.endswith('.swift') else 'image.icns' if path.endswith('.icns') else 'text.plist.xml' if path.endswith('.plist') else 'text.json' if path.endswith('.json') else 'file'
    obj(path, f'isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(path)}; sourceTree = SOURCE_ROOT;')
for path in sources + tests + test_fixtures + ios_sources + ios_tests + ios_ui + resources:
    obj('build:'+path, f'isa = PBXBuildFile; fileRef = {uid(path)};')
obj('appProduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Dayline.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('testProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DaylineTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('sourceGroup', f'isa = PBXGroup; name = Sources; children = {ids(sources)}; sourceTree = "<group>";')
obj('testGroup', f'isa = PBXGroup; name = Tests; children = {ids(tests)}; sourceTree = "<group>";')
obj('fixtureGroup', f'isa = PBXGroup; name = Fixtures; children = {ids(test_fixtures)}; sourceTree = "<group>";')
obj('resourceGroup', f'isa = PBXGroup; name = Resources; children = {ids(resources+["Resources/Info.plist"])}; sourceTree = "<group>";')
obj('iosProduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = DaylineIOS.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('iosTestProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DaylineIOSTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('iosSourceGroup', f'isa = PBXGroup; name = DaylineIOS; children = {ids(ios_sources)}; sourceTree = "<group>";')
obj('iosTestGroup', f'isa = PBXGroup; name = DaylineIOSTests; children = {ids(ios_tests)}; sourceTree = "<group>";')
obj('iosUIProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DaylineIOSUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('iosUITestGroup', f'isa = PBXGroup; name = DaylineIOSUITests; children = {ids(ios_ui)}; sourceTree = "<group>";')
product_children = ["appProduct", "testProduct"] + (["iosProduct", "iosTestProduct"] + (["iosUIProduct"] if ios_ui else []) if ios_sources else [])
group_children = ["sourceGroup","testGroup","fixtureGroup","iosSourceGroup","iosTestGroup"] + (["iosUITestGroup"] if ios_ui else []) + ["resourceGroup","README.md","products"] if ios_sources else ["sourceGroup","testGroup","fixtureGroup","resourceGroup","README.md","products"]
obj('products', f'isa = PBXGroup; name = Products; children = {ids(product_children)}; sourceTree = "<group>";')
obj('rootGroup', f'isa = PBXGroup; children = {ids(group_children)}; sourceTree = "<group>";')
for key, paths, phase in [('appSources', sources, 'PBXSourcesBuildPhase'), ('testSources', tests, 'PBXSourcesBuildPhase'), ('appResources', resources, 'PBXResourcesBuildPhase')]:
    obj(key, f'isa = {phase}; buildActionMask = 2147483647; files = {ids(["build:"+p for p in paths]) if paths else "()"}; runOnlyForDeploymentPostprocessing = 0;')
obj('testResources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {ids(["build:"+p for p in test_fixtures]) if test_fixtures else "()"}; runOnlyForDeploymentPostprocessing = 0;')
obj('iosSources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {ids(["build:"+p for p in ios_sources]) if ios_sources else "()"}; runOnlyForDeploymentPostprocessing = 0;')
obj('iosTestSources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {ids(["build:"+p for p in ios_tests]) if ios_tests else "()"}; runOnlyForDeploymentPostprocessing = 0;')
obj('iosUISources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {ids(["build:"+p for p in ios_ui]) if ios_ui else "()"}; runOnlyForDeploymentPostprocessing = 0;')
obj('appFrameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {ids(["build:DaylineCore","build:DaylineData"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('testFrameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {ids(["build:DaylineCoreTests","build:DaylineDataTests"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('iosFrameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {ids(["build:DaylineCoreIOS","build:DaylineDataIOS"])}; runOnlyForDeploymentPostprocessing = 0;')
obj('iosTestFrameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {ids(["build:DaylineCoreIOSTests","build:DaylineDataIOSTests"])}; runOnlyForDeploymentPostprocessing = 0;')
for key, product, package in [
    ('build:DaylineCore', 'pkg:DaylineCore', 'localpkg'),
    ('build:DaylineCoreTests', 'pkg:DaylineCoreTests', 'localpkg'),
    ('build:DaylineData', 'pkg:DaylineData', 'localpkgData'),
    ('build:DaylineDataTests', 'pkg:DaylineDataTests', 'localpkgData'),
    ('build:DaylineCoreIOS', 'pkg:DaylineCoreIOS', 'localpkg'),
    ('build:DaylineDataIOS', 'pkg:DaylineDataIOS', 'localpkgData'),
    ('build:DaylineCoreIOSTests', 'pkg:DaylineCoreIOSTests', 'localpkg'),
    ('build:DaylineDataIOSTests', 'pkg:DaylineDataIOSTests', 'localpkgData'),
]:
    obj(key, f'isa = PBXBuildFile; productRef = {uid(product)};')
    obj(product, f'isa = XCSwiftPackageProductDependency; package = {uid(package)}; productName = {("DaylineCore" if "Core" in product else "DaylineData")};')
obj('localpkg', 'isa = XCLocalSwiftPackageReference; relativePath = Packages/DaylineCore;')
obj('localpkgData', 'isa = XCLocalSwiftPackageReference; relativePath = Packages/DaylineData;')
common = {'SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_IDENTITY':'-','COMBINE_HIDPI_IMAGES':'YES'}
ios_common = {'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_IDENTITY':'-','CODE_SIGNING_REQUIRED':'NO','CODE_SIGNING_ALLOWED':'YES','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','ENABLE_PREVIEWS':'YES','ARCHS':'arm64','EXCLUDED_ARCHS':'x86_64'}
scopes = ['project','app','test'] + (['ios','iostest'] + (['iosui'] if ios_ui else []) if ios_sources else [])
for scope in scopes:
    for mode in ['Debug','Release']:
        settings = dict(common) if scope == 'project' else {}
        if scope == 'project':
            settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode == 'Debug' else '-O','SWIFT_COMPILATION_MODE':'singlefile' if mode == 'Debug' else 'wholemodule','DEBUG_INFORMATION_FORMAT':'dwarf' if mode == 'Debug' else 'dwarf-with-dsym','ENABLE_TESTABILITY':'YES' if mode == 'Debug' else 'NO','ONLY_ACTIVE_ARCH':'YES' if mode == 'Debug' else 'NO'})
        elif scope == 'app':
            settings.update({'PRODUCT_NAME':'Dayline','PRODUCT_BUNDLE_IDENTIFIER':'app.dayline.mac','INFOPLIST_FILE':'Resources/Info.plist','GENERATE_INFOPLIST_FILE':'NO','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks','ENABLE_APP_SANDBOX':'NO','CURRENT_PROJECT_VERSION':'3','MARKETING_VERSION':'1.1.1'})
        elif scope == 'test':
            settings.update({'PRODUCT_NAME':'DaylineTests','PRODUCT_BUNDLE_IDENTIFIER':'app.dayline.mac.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Dayline.app/Contents/MacOS/Dayline','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'})
        elif scope == 'ios':
            settings = dict(ios_common)
            settings.update({'PRODUCT_NAME':'DaylineIOS','PRODUCT_BUNDLE_IDENTIFIER':'app.dayline.ios','INFOPLIST_FILE':'Resources/iOS/Info.plist','GENERATE_INFOPLIST_FILE':'NO','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.1.0','TARGETED_DEVICE_FAMILY':'1'})
        elif scope == 'iosui':
            settings = dict(ios_common)
            settings.update({'PRODUCT_NAME':'DaylineIOSUITests','PRODUCT_BUNDLE_IDENTIFIER':'app.dayline.ios.uitests','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'DaylineIOS','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
        else:
            settings = dict(ios_common)
            settings.update({'PRODUCT_NAME':'DaylineIOSTests','PRODUCT_BUNDLE_IDENTIFIER':'app.dayline.ios.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/DaylineIOS.app/DaylineIOS','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @loader_path/Frameworks'})
        body = ' '.join(f'{k} = {q(v)};' for k,v in settings.items())
        obj(scope+mode, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {mode};')
    obj(scope+'Configs', f'isa = XCConfigurationList; buildConfigurations = {ids([scope+"Debug",scope+"Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("app")}; remoteInfo = Dayline;')
obj('dependency', f'isa = PBXTargetDependency; target = {uid("app")}; targetProxy = {uid("proxy")};')
obj('app', f'isa = PBXNativeTarget; buildConfigurationList = {uid("appConfigs")}; buildPhases = {ids(["appSources","appFrameworks","appResources"])}; buildRules = (); dependencies = (); name = Dayline; packageProductDependencies = {ids(["pkg:DaylineCore","pkg:DaylineData"])}; productName = Dayline; productReference = {uid("appProduct")}; productType = "com.apple.product-type.application";')
obj('test', f'isa = PBXNativeTarget; buildConfigurationList = {uid("testConfigs")}; buildPhases = {ids(["testSources","testFrameworks","testResources"])}; buildRules = (); dependencies = {ids(["dependency"])}; name = DaylineTests; packageProductDependencies = {ids(["pkg:DaylineCoreTests","pkg:DaylineDataTests"])}; productName = DaylineTests; productReference = {uid("testProduct")}; productType = "com.apple.product-type.bundle.unit-test";')
targets = ["app","test"]
if ios_sources:
    obj('iosProxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("ios")}; remoteInfo = DaylineIOS;')
    obj('iosDependency', f'isa = PBXTargetDependency; target = {uid("ios")}; targetProxy = {uid("iosProxy")};')
    obj('ios', f'isa = PBXNativeTarget; buildConfigurationList = {uid("iosConfigs")}; buildPhases = {ids(["iosSources","iosFrameworks"])}; buildRules = (); dependencies = (); name = DaylineIOS; packageProductDependencies = {ids(["pkg:DaylineCoreIOS","pkg:DaylineDataIOS"])}; productName = DaylineIOS; productReference = {uid("iosProduct")}; productType = "com.apple.product-type.application";')
    obj('iostest', f'isa = PBXNativeTarget; buildConfigurationList = {uid("iostestConfigs")}; buildPhases = {ids(["iosTestSources","iosTestFrameworks"])}; buildRules = (); dependencies = {ids(["iosDependency"])}; name = DaylineIOSTests; packageProductDependencies = {ids(["pkg:DaylineCoreIOSTests","pkg:DaylineDataIOSTests"])}; productName = DaylineIOSTests; productReference = {uid("iosTestProduct")}; productType = "com.apple.product-type.bundle.unit-test";')
    targets += ["ios","iostest"]
    if ios_ui:
        obj('iosUIProxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("ios")}; remoteInfo = DaylineIOS;')
        obj('iosUIDependency', f'isa = PBXTargetDependency; target = {uid("ios")}; targetProxy = {uid("iosUIProxy")};')
        obj('iosui', f'isa = PBXNativeTarget; buildConfigurationList = {uid("iosuiConfigs")}; buildPhases = {ids(["iosUISources"])}; buildRules = (); dependencies = {ids(["iosUIDependency"])}; name = DaylineIOSUITests; productName = DaylineIOSUITests; productReference = {uid("iosUIProduct")}; productType = "com.apple.product-type.bundle.ui-testing";')
        targets += ["iosui"]
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectConfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (en, zh_CN, Base); mainGroup = {uid("rootGroup")}; packageReferences = {ids(["localpkg","localpkgData"])}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = {ids(targets)};')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n'+'\n'.join(objects)+'\n\t};\n\trootObject = '+uid('project')+';\n}\n')
scheme_dir = project/'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
def ref(key,name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(key)}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:Dayline.xcodeproj"/>'
app_ref = ref('app','Dayline.app')
(scheme_dir/'Dayline.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO"><Testables><TestableReference skipped="NO">{ref('test','DaylineTests.xctest')}</TestableReference></Testables><EnvironmentVariables><EnvironmentVariable key="DAYLINE_XCTEST_MODE" value="1" isEnabled="YES"/></EnvironmentVariables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
if ios_sources:
    ios_ref = ref('ios', 'DaylineIOS.app')
    (scheme_dir/'DaylineIOS.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ios_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO"><Testables><TestableReference skipped="NO">{ref('iostest','DaylineIOSTests.xctest')}</TestableReference>{f'<TestableReference skipped="NO">{ref("iosui","DaylineIOSUITests.xctest")}</TestableReference>' if ios_ui else ''}</Testables><EnvironmentVariables><EnvironmentVariable key="DAYLINE_XCTEST_MODE" value="1" isEnabled="YES"/></EnvironmentVariables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ios_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ios_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(f'Generated {project} ({len(sources)} Mac sources, {len(ios_sources)} iOS sources, {len(tests)} Mac tests)')
