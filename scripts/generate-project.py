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
def ids(values): return '(' + ', '.join(uid(x) for x in values) + ',)'
sources = [str(p.relative_to(root)) for p in sorted((root/'Sources').rglob('*.swift'))]
tests = [str(p.relative_to(root)) for p in sorted((root/'Tests').rglob('*.swift'))]
resources = ['Resources/Dayline.icns'] if (root/'Resources/Dayline.icns').exists() else []
for path in sources + tests + resources + ['Resources/Info.plist', 'README.md']:
    filetype = 'sourcecode.swift' if path.endswith('.swift') else 'image.icns' if path.endswith('.icns') else 'text.plist.xml' if path.endswith('.plist') else 'text'
    obj(path, f'isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(path)}; sourceTree = SOURCE_ROOT;')
for path in sources + tests + resources:
    obj('build:'+path, f'isa = PBXBuildFile; fileRef = {uid(path)};')
obj('appProduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Dayline.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj('testProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = DaylineTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
obj('sourceGroup', f'isa = PBXGroup; name = Sources; children = {ids(sources)}; sourceTree = "<group>";')
obj('testGroup', f'isa = PBXGroup; name = Tests; children = {ids(tests)}; sourceTree = "<group>";')
obj('resourceGroup', f'isa = PBXGroup; name = Resources; children = {ids(resources+["Resources/Info.plist"])}; sourceTree = "<group>";')
obj('products', f'isa = PBXGroup; name = Products; children = {ids(["appProduct", "testProduct"])}; sourceTree = "<group>";')
obj('rootGroup', f'isa = PBXGroup; children = {ids(["sourceGroup","testGroup","resourceGroup","README.md","products"])}; sourceTree = "<group>";')
for key, paths, phase in [('appSources',sources,'PBXSourcesBuildPhase'),('testSources',tests,'PBXSourcesBuildPhase'),('appResources',resources,'PBXResourcesBuildPhase'),('appFrameworks',[],'PBXFrameworksBuildPhase'),('testFrameworks',[],'PBXFrameworksBuildPhase')]:
    obj(key, f'isa = {phase}; buildActionMask = 2147483647; files = {ids(["build:"+p for p in paths]) if paths else "()"}; runOnlyForDeploymentPostprocessing = 0;')
common = {'SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'14.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_IDENTITY':'-','COMBINE_HIDPI_IMAGES':'YES'}
for scope in ['project','app','test']:
    for mode in ['Debug','Release']:
        settings = dict(common) if scope == 'project' else {}
        if scope == 'project':
            settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode == 'Debug' else '-O','SWIFT_COMPILATION_MODE':'singlefile' if mode == 'Debug' else 'wholemodule','DEBUG_INFORMATION_FORMAT':'dwarf' if mode == 'Debug' else 'dwarf-with-dsym','ENABLE_TESTABILITY':'YES' if mode == 'Debug' else 'NO'})
        elif scope == 'app':
            settings.update({'PRODUCT_NAME':'Dayline','PRODUCT_BUNDLE_IDENTIFIER':'app.dayline.mac','INFOPLIST_FILE':'Resources/Info.plist','GENERATE_INFOPLIST_FILE':'NO','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks','ENABLE_APP_SANDBOX':'NO','CURRENT_PROJECT_VERSION':'3','MARKETING_VERSION':'1.1.1'})
        else:
            settings.update({'PRODUCT_NAME':'DaylineTests','PRODUCT_BUNDLE_IDENTIFIER':'app.dayline.mac.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Dayline.app/Contents/MacOS/Dayline','BUNDLE_LOADER':'$(TEST_HOST)','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'})
        body = ' '.join(f'{k} = {q(v)};' for k,v in settings.items())
        obj(scope+mode, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {mode};')
    obj(scope+'Configs', f'isa = XCConfigurationList; buildConfigurations = {ids([scope+"Debug",scope+"Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("app")}; remoteInfo = Dayline;')
obj('dependency', f'isa = PBXTargetDependency; target = {uid("app")}; targetProxy = {uid("proxy")};')
obj('app', f'isa = PBXNativeTarget; buildConfigurationList = {uid("appConfigs")}; buildPhases = {ids(["appSources","appFrameworks","appResources"])}; buildRules = (); dependencies = (); name = Dayline; productName = Dayline; productReference = {uid("appProduct")}; productType = "com.apple.product-type.application";')
obj('test', f'isa = PBXNativeTarget; buildConfigurationList = {uid("testConfigs")}; buildPhases = {ids(["testSources","testFrameworks"])}; buildRules = (); dependencies = {ids(["dependency"])}; name = DaylineTests; productName = DaylineTests; productReference = {uid("testProduct")}; productType = "com.apple.product-type.bundle.unit-test";')
obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectConfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = zh_CN; hasScannedForEncodings = 0; knownRegions = (en, zh_CN, Base); mainGroup = {uid("rootGroup")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = {ids(["app","test"])};')
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
print(f'Generated {project} ({len(sources)} source files, {len(tests)} test files)')
