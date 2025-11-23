(module
  (import "env" "print_mem" (func $print_mem (param i32 i32)))
  (import "env" "print_val" (func $print_val (param i32)))
  (import "env" "print_char" (func $print_char (param i32)))
  (import "env" "read_file" (func $read_file (param i32 i32 i32 i32) (result i32)))
  (import "env" "read_char" (func $read_char (result i32)))

  (memory $mem 1)

  (global $file_name_offset i32 (i32.const 0))
  (global $file_name_size i32 (i32.const 7))
  (global $instr_map_offset i32 (i32.const 50))
  (global $instr_map_size i32 (i32.const 8))
  (global $text_offset i32 (i32.const 100))
  (global $text_max_size i32 (i32.const 10000))
  (global $data_offset i32 (i32.const 10200))
  (global $data_size i32 (i32.const 30000))

  ;; data cannot use global variables

  ;; $file_name_offset
  (data (i32.const 0) "main.bf")

  ;; $instr_map_offset
  (data (i32.const 50) "+-<>[].,")

  (func $read_text (result i32)
    (call $read_file
      (global.get $file_name_offset)
      (global.get $file_name_size)
      (global.get $text_offset)
      (global.get $text_max_size)
    )
  )

  (func $wrap_increment (param $x i32) (param $m i32) (result i32)
    (i32.rem_u
      (i32.add
        (local.get $x)
        (i32.const 1)
      )
      (local.get $m)
    )
  )

  (func $wrap_decrement (param $x i32) (param $m i32) (result i32)
    (i32.rem_u
      (i32.sub
        (local.get $x)
        (i32.const 1)
      )
      (local.get $m)
    )
  )

  (func $map_char_to_index (param $char i32) (result i32)
    (local $i i32)

    (local.set $i
      (i32.const 0)
    )

    (block $loop_exit
      (loop $loop
        (br_if $loop_exit
          (i32.ge_u
            (local.get $i)
            (global.get $instr_map_size)
          )
        )

        local.get $i
        global.get $instr_map_offset
        i32.add
        i32.load8_u

        (if
          (i32.eq (local.get $char))
          (then
            local.get $i
            return
          )
        )

        (local.set $i
          (i32.add
            (local.get $i)
            (i32.const 1)
          )
        )

        br $loop
      )
    )

    ;; for comments
    i32.const 8
  )

  ;; preprocessing means that each instruction char (eg. '+', '<' ...)
  ;; is mapped to its corresponding index that $execute_text uses in br_table
  (func $preprocess_text (param $text_end i32)
    (local $i i32)

    (local.set $i
      (global.get $text_offset)
    )

    (block $loop_exit
      (loop $loop
        (br_if $loop_exit
          (i32.ge_u
            (local.get $i)
            (local.get $text_end)
          )
        )

        local.get $i
        local.get $i
        i32.load8_u
        call $map_char_to_index
        i32.store8

        (local.set $i
          (i32.add
            (local.get $i)
            (i32.const 1)
          )
        )

        br $loop
      )
    )
  )

  (func $skip_to_loop_end (param $text_end i32) (param $init_text_ptr i32) (result i32)
    (local $text_ptr i32)

    local.get $init_text_ptr
    local.set $text_ptr

    (block $loop_exit
      (loop $loop
        (br_if $loop_exit
          (i32.ge_u
            (local.get $text_ptr)
            (local.get $text_end)
          )
        )

        local.get $text_ptr
        i32.load8_u
        i32.const 5 ;; ']' code
        
        (if
          (i32.eq)
          (then
            br $loop_exit
          )
        )

        (local.set $text_ptr
          (i32.add
            (local.get $text_ptr)
            (i32.const 1)
          )
        )

        br $loop
      )
    )

    local.get $text_ptr
    i32.const 1
    i32.add
  )

  (func $execute_text (param $text_end i32) (param $init_text_ptr i32) (param $init_data_ptr i32) (result i32)
    (local $text_ptr i32)
    (local $data_ptr i32)

    local.get $init_text_ptr
    local.set $text_ptr
    
    local.get $init_data_ptr
    local.set $data_ptr

    (block $text_loop_exit
      (loop $text_loop
        (br_if $text_loop_exit
          (i32.ge_u
            (local.get $text_ptr)
            (local.get $text_end)
          )
        )
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        (block $switch_end
          (block $case_default
            (block $case_increment
              (block $case_decrement
                (block $case_move_left
                  (block $case_move_right
                    (block $case_loop_start
                      (block $case_loop_end
                        (block $case_output
                          (block $case_input
                            local.get $text_ptr
                            i32.load8_u

                            (br_table
                              $case_increment
                              $case_decrement
                              $case_move_left
                              $case_move_right
                              $case_loop_start
                              $case_loop_end
                              $case_output
                              $case_input
                              $case_default
                            )
                          )
                          ;; Input branch
                          local.get $data_ptr
                          call $read_char
                          i32.store8
                          br $switch_end
                        )
                        ;; Output branch
                        local.get $data_ptr
                        i32.load8_u
                        call $print_char
                        br $switch_end
                      )
                      ;; Loop end branch
                      local.get $data_ptr
                      i32.load8_u
                      (if
                        (i32.eqz)
                        (then
                          local.get $text_ptr
                          i32.const 1
                          i32.add
                          return
                        )
                        (else
                          local.get $init_text_ptr
                          i32.const 1
                          i32.sub
                          return
                        )
                      )
                    )
                    ;; Loop start branch
                    local.get $data_ptr
                    i32.load8_u
                    (if (result i32)
                      (i32.eqz)
                      (then
                        local.get $text_end
                        local.get $text_ptr
                        call $skip_to_loop_end
                      )
                      (else
                        local.get $text_end
                        local.get $text_ptr
                        i32.const 1
                        i32.add
                        local.get $data_ptr
                        call $execute_text
                      )
                    )

                    local.set $text_ptr
                    br $text_loop ;; We dont want to increment the text_ptr
                  )
                  ;; Move right branch
                  local.get $data_ptr
                  global.get $data_size
                  call $wrap_increment
                  local.set $data_ptr
                  br $switch_end
                )
                ;; Move left branch
                local.get $data_ptr
                global.get $data_size
                call $wrap_decrement
                local.set $data_ptr
                br $switch_end
              )
              ;; Decrement branch
              local.get $data_ptr
              local.get $data_ptr
              i32.load8_u
              i32.const 256
              call $wrap_decrement
              i32.store8
              br $switch_end
            )
            ;; Increment branch
            local.get $data_ptr
            local.get $data_ptr
            i32.load8_u
            i32.const 256
            call $wrap_increment
            i32.store8
            br $switch_end
          )
        )

        ;; Default branch - do nothing

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        (local.set $text_ptr
          (i32.add
            (local.get $text_ptr)
            (i32.const 1)
          )
        )

        br $text_loop
      )
    )

    ;; End of loop
    ;; if there are other layers it will break them right off
    ;; because the it will load -1 as unsigned int
    i32.const -1
  )

  (func $main
    (local $text_size i32)
    (local $text_end i32)

    call $read_text
    local.set $text_size

    (local.set $text_end
      (i32.add
        (global.get $text_offset)
        (local.get $text_size)
      )
    )

    local.get $text_end
    call $preprocess_text

    local.get $text_end
    global.get $text_offset
    global.get $data_offset
    call $execute_text
    return
  )

  (export "memory" (memory $mem))
  (export "main" (func $main))
)
