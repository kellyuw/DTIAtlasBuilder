cmake_minimum_required(VERSION 2.8)
CMAKE_POLICY(VERSION 2.8)

#======================================================================================
# Generation of moc_GUI.cxx does not need all Slicer libs so do it first to avoid processing long cmd line with all libs

find_package(Qt4 REQUIRED)
include(${QT_USE_FILE})

QT4_ADD_RESOURCES(RCC_SRCS DTIAtlasBuilder.qrc) # QResource for the icon
QT4_WRAP_CPP(QtProject_HEADERS_MOC GUI.h)
QT4_WRAP_UI(UI_FILES GUIwindow.ui)

#======================================================================================

find_package(GenerateCLP REQUIRED)
include(${GenerateCLP_USE_FILE})

#======================================================================================
# As the external project gives this CMakeLists the paths to the needed libraries (*_DIR), find_package will just use the existing *_DIR
set(ITK_IO_MODULES_USED 
ITKIOImageBase
ITKIONRRD
ITKIOBMP
ITKIOGIPL
ITKIOHDF5
ITKIOIPL
ITKIOJPEG
ITKIOLSM
ITKIOMRC
ITKIOMesh
ITKIOMeta
ITKIONIFTI
ITKIOPNG
ITKIORAW
ITKIOTIFF
ITKIOVTK
ITKIOGDCM
)

find_package(ITK COMPONENTS
  ITKCommon
  ITKIOImageBase
  ITKImageIntensity
  ITKTestKernel
  ${ITK_IO_MODULES_USED}
)
include(${ITK_USE_FILE})

include_directories(${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

#======================================================================================
# Compile step for DTIAtlasBuilder
if(DTIAtlasBuilder_BUILD_SLICER_EXTENSION) # to configure GUI.cxx
  set(SlicerExtCXXVar "true")
  find_package(Slicer REQUIRED)
  include(${Slicer_USE_FILE})
else(DTIAtlasBuilder_BUILD_SLICER_EXTENSION)
  set(SlicerExtCXXVar "false")
endif(DTIAtlasBuilder_BUILD_SLICER_EXTENSION)

# Add the compilation date in xml file for it to appear in --help
if(WIN32)
  execute_process(COMMAND "cmd" " /C date /T" OUTPUT_VARIABLE TODAY)
  string(REGEX REPLACE "....(..)/(..)/(....).*" "\\1/\\2/\\3" TODAY ${TODAY}) # to remove the end of line and the name of day at the beginning
else() # Unix
  execute_process(COMMAND "date" "+%m/%d/%Y" OUTPUT_VARIABLE TODAY)
  string(REGEX REPLACE "(..)/(..)/(....).*" "\\1/\\2/\\3" TODAY ${TODAY}) # to remove the end of line
endif()

configure_file(DTIAtlasBuilder.xml.in ${CMAKE_CURRENT_BINARY_DIR}/DTIAtlasBuilder.xml)
# xml info in GUI
file(READ ${CMAKE_CURRENT_BINARY_DIR}/DTIAtlasBuilder.xml var)

string(REGEX MATCH "<version>.*</version>" ext "${var}")
string(REPLACE "<version>" "" version_number ${ext} )
string(REPLACE "</version>" "" version_number ${version_number})

ADD_DEFINITIONS(-DDTIAtlasBuilder_VERSION="${version_number}")

# DTIAtlasBuilder target
GENERATECLP(DTIABsources ${CMAKE_CURRENT_BINARY_DIR}/DTIAtlasBuilder.xml) # include the GCLP file to the project
if( EXTENSION_SUPERBUILD_BINARY_DIR )
  add_executable( DTIAtlasBuilderLauncher Launcher.cxx ${DTIABsources} )
  install( TARGETS DTIAtlasBuilderLauncher DESTINATION bin )
endif()
list( APPEND DTIABsources DTIAtlasBuilder.cxx GUI.h GUI.cxx ScriptWriter.h ScriptWriter.cxx ${QtProject_HEADERS_MOC} ${UI_FILES} ${RCC_SRCS})
add_executable(DTIAtlasBuilder ${DTIABsources})  # add the files contained by "DTIABsources" to the project
set_target_properties(DTIAtlasBuilder PROPERTIES COMPILE_FLAGS "-DDTIAtlasBuilder_BUILD_SLICER_EXTENSION=${SlicerExtCXXVar}")# Add preprocessor definitions
target_link_libraries(DTIAtlasBuilder ${QT_LIBRARIES} ${ITK_LIBRARIES})
install(TARGETS DTIAtlasBuilder DESTINATION bin)

#======================================================================================
# Testing for DTIAtlasBuilder
if(BUILD_TESTING)
  configure_file( ${CMAKE_CURRENT_SOURCE_DIR}/Testing/DTIAtlasBuilderSoftConfig.txt.in ${CMAKE_CURRENT_BINARY_DIR}/Testing/DTIAtlasBuilderSoftConfig.txt)
  set(TestingSRCdirectory ${CMAKE_CURRENT_SOURCE_DIR}/Testing)
  set(TestingBINdirectory ${CMAKE_CURRENT_BINARY_DIR}/Testing)
  set(TestDataFolder ${CMAKE_CURRENT_SOURCE_DIR}/Data/Testing)
  add_library(DTIAtlasBuilderLib STATIC ${DTIABsources}) # STATIC is also the default
  set_target_properties(DTIAtlasBuilderLib PROPERTIES COMPILE_FLAGS "-Dmain=ModuleEntryPoint -DDTIAtlasBuilder_BUILD_SLICER_EXTENSION=${SlicerExtCXXVar}") # replace the main in DTIAtlasBuilder.cxx by the itkTest function ModuleEntryPoint
  target_link_libraries(DTIAtlasBuilderLib ${QT_LIBRARIES} ${ITK_LIBRARIES})
  set_target_properties(DTIAtlasBuilderLib PROPERTIES LABELS DTIAtlasBuilder)
  # Create Tests
  include(CTest)
  add_subdirectory( ${TestingSRCdirectory} ) # contains a CMakeLists.txt
#  include_directories( ${TestingSRCdirectory} ) # contains a CMakeLists.txt
endif()
