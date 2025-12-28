# Podfile for berrry-joyful

platform :osx, '14.0'

target 'berrry-joyful' do
  use_frameworks!

  # JoyConSwift - IOKit wrapper for Nintendo Joy-Con and ProController
  pod 'JoyConSwift'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    end
  end

  # Patch JoyConSwift Utils.swift to fix pointer alignment crash
  # See: https://github.com/magicien/JoyConSwift/issues/XXX
  utils_path = 'Pods/JoyConSwift/Source/Utils.swift'
  if File.exist?(utils_path)
    puts "Patching #{utils_path} to fix pointer alignment issue..."

    utils_content = File.read(utils_path)

    # Check if already patched
    if utils_content.include?('let byte0 = UInt32(ptr[0])')
      puts "  ✓ Already patched, skipping"
    else
      # Replace unsafe pointer operations with safe byte-by-byte reading
      patched_content = utils_content.gsub(
        /func ReadUInt32\(from ptr: UnsafePointer<UInt8>\) -> UInt32 \{.*?withMemoryRebound.*?\n\}/m,
        'func ReadUInt32(from ptr: UnsafePointer<UInt8>) -> UInt32 {
    let byte0 = UInt32(ptr[0])
    let byte1 = UInt32(ptr[1])
    let byte2 = UInt32(ptr[2])
    let byte3 = UInt32(ptr[3])
    return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
}'
      ).gsub(
        /func ReadInt32\(from ptr: UnsafePointer<UInt8>\) -> Int32 \{.*?withMemoryRebound.*?\n\}/m,
        'func ReadInt32(from ptr: UnsafePointer<UInt8>) -> Int32 {
    let byte0 = Int32(ptr[0])
    let byte1 = Int32(ptr[1])
    let byte2 = Int32(ptr[2])
    let byte3 = Int32(ptr[3])
    return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
}'
      ).gsub(
        /func ReadUInt16\(from ptr: UnsafePointer<UInt8>\) -> UInt16 \{.*?withMemoryRebound.*?\n\}/m,
        'func ReadUInt16(from ptr: UnsafePointer<UInt8>) -> UInt16 {
    let byte0 = UInt16(ptr[0])
    let byte1 = UInt16(ptr[1])
    return byte0 | (byte1 << 8)
}'
      ).gsub(
        /func ReadInt16\(from ptr: UnsafePointer<UInt8>\) -> Int16 \{.*?withMemoryRebound.*?\n\}/m,
        'func ReadInt16(from ptr: UnsafePointer<UInt8>) -> Int16 {
    let byte0 = Int16(ptr[0])
    let byte1 = Int16(ptr[1])
    return byte0 | (byte1 << 8)
}'
      )

      File.write(utils_path, patched_content)
      puts "  ✓ Patched successfully"
    end
  else
    puts "  ⚠ Warning: #{utils_path} not found, skipping patch"
  end
end
