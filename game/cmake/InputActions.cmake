find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(COMMAND "${Python3_EXECUTABLE}" -c "import yaml; assert yaml.__version__ == '6.0.3'"
    RESULT_VARIABLE INPUT_YAML_RESULT ERROR_QUIET)
if(NOT INPUT_YAML_RESULT EQUAL 0)
    message(FATAL_ERROR "Input generation requires PyYAML 6.0.3. Run: ${Python3_EXECUTABLE} -m pip install -r ${CMAKE_CURRENT_SOURCE_DIR}/tools/requirements-input.txt")
endif()
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CANIS_PROJECT_CONFIG}")
execute_process(COMMAND "${Python3_EXECUTABLE}" -c
    "import yaml,sys; print(yaml.safe_load(open(sys.argv[1])).get('inputAsset','project_settings/input.canis'))"
    "${CANIS_PROJECT_CONFIG}" OUTPUT_VARIABLE INPUT_ASSET_RELATIVE OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY)
if(IS_ABSOLUTE "${INPUT_ASSET_RELATIVE}" OR INPUT_ASSET_RELATIVE MATCHES "(^|/)\\.\\.(/|$)")
    message(FATAL_ERROR "inputAsset must be a project-relative path without parent traversal")
endif()
set(INPUT_ASSET "${CMAKE_SOURCE_DIR}/${INPUT_ASSET_RELATIVE}")
set(INPUT_GENERATOR "${CMAKE_CURRENT_SOURCE_DIR}/tools/generate_input_actions.py")
set(INPUT_CATALOG "${CMAKE_SOURCE_DIR}/canis/include/Canis/InputControls.inl")
file(GLOB_RECURSE INPUT_STEAM_CONFIGS CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/project_settings/steam/*.vdf" "${CMAKE_SOURCE_DIR}/project_settings/steam/*.canis")
set(INPUT_HEADER "${CMAKE_CURRENT_BINARY_DIR}/generated/InputActions.generated.hpp")
set(INPUT_STAMP "${CMAKE_CURRENT_BINARY_DIR}/generated/input-actions.stamp")
get_filename_component(INPUT_ASSET_DIRECTORY "${INPUT_ASSET_RELATIVE}" DIRECTORY)
add_custom_command(OUTPUT "${INPUT_STAMP}"
    BYPRODUCTS "${INPUT_HEADER}"
    COMMAND "${Python3_EXECUTABLE}" "${INPUT_GENERATOR}" --input "${INPUT_ASSET}"
        --catalog "${INPUT_CATALOG}" --output "${INPUT_HEADER}"
        --steam-dir "${CMAKE_CURRENT_BINARY_DIR}/generated/steam"
        --configurations "${CMAKE_SOURCE_DIR}/project_settings/steam/configurations.canis"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}/generated/steam" "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/project_settings/steam"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${INPUT_ASSET_DIRECTORY}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${INPUT_ASSET}" "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${INPUT_ASSET_RELATIVE}"
    COMMAND "${CMAKE_COMMAND}" -E touch "${INPUT_STAMP}"
    DEPENDS "${INPUT_ASSET}" "${INPUT_GENERATOR}" "${INPUT_CATALOG}" "${CANIS_PROJECT_CONFIG}" ${INPUT_STEAM_CONFIGS}
    VERBATIM)
add_custom_target(GenerateInputActions DEPENDS "${INPUT_STAMP}")
if(BUILD_TESTING AND NOT CANIS_PLATFORM_WEB)
    add_test(NAME InputActionsGeneratorTests COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_input_generator.py")
    add_test(NAME InputActionsSteamOptionsTests COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_input_options.py")
endif()

if(CANIS_PLATFORM_WEB)
    target_link_options(${PROJECT_NAME} PRIVATE "SHELL:--preload-file ${INPUT_ASSET}@/${INPUT_ASSET_RELATIVE}")
    set_property(TARGET ${PROJECT_NAME} APPEND PROPERTY LINK_DEPENDS "${INPUT_ASSET}" "${CANIS_PROJECT_CONFIG}")
    add_dependencies(${PROJECT_NAME} GenerateInputActions)
endif()
