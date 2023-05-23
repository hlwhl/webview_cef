function(extract_file filename extract_dir)
    message(STATUS "${filename} will extract to ${extract_dir} ...")

    set(temp_dir ${CMAKE_BINARY_DIR}/tmp_for_extract.dir)
    if(EXISTS ${temp_dir})
        file(REMOVE_RECURSE ${temp_dir})
    endif()
    file(MAKE_DIRECTORY ${temp_dir})
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar -xf ${filename}
            WORKING_DIRECTORY ${temp_dir})

    file(GLOB contents "${temp_dir}/*")
    list(LENGTH contents n)
    if(NOT n EQUAL 1 OR NOT IS_DIRECTORY "${contents}")
        set(contents "${temp_dir}")
    endif()

    get_filename_component(contents ${contents} ABSOLUTE)

    file(INSTALL "${contents}/" DESTINATION ${extract_dir})
    
    file(REMOVE_RECURSE ${temp_dir})
endfunction()

function(download_file url filename)
  message(STATUS "Download ${url} to ${filename} ...")
  file(DOWNLOAD ${url} ${filename} SHOW_PROGRESS)
endfunction()

function(preparePrebuiltFiles)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cefbins/debug")
        download_file(https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_windows/webview_cef_bin_0.0.2_101.0.18+chromium-101.0.4951.67_windows64.zip ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt.zip)
        file(MAKE_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/cefbins)
        extract_file(${CMAKE_CURRENT_SOURCE_DIR}/prebuilt.zip ${CMAKE_CURRENT_SOURCE_DIR}/cefbins)
        file(REMOVE_RECURSE ${CMAKE_CURRENT_SOURCE_DIR}/prebuilt.zip)
    endif()
endfunction()