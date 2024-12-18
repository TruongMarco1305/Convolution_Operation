.data
input_filename:        .asciiz "input_matrix.txt"
output_filename:       .asciiz "output_matrix.txt"
buffer:                .space 100000          
float_thousand:        .float 10000.0
float_convertedline:   .asciiz "\n"
kernel_image_error_message: .asciiz "Kernel is larger than the Image"
not_constrain_error_message: .asciiz "Some input is not in the constrain"

N: .word 0
M: .word 0
p: .word 0
s: .word 0
padded_size: .word 0
out_size: .word 0
# Image Matrix
image: .space 1000
# Padded Image Matrix
padded_image: .space 1000
# Filter Matrix
kernel: .space 1000
# Output Matrix
out: .space 1000
float_string_buffer: .space 64       # Buffer to hold float as string
int_temp_buffer: .space 32 
space_char:          .byte ' '  
float_ten:         .float 10.0   

.text
.globl main

main:
    # Open input file
    li $v0, 13               
    la $a0, input_filename     
    li $a1, 0                  
    syscall
    move $s7, $v0            

    # Read the first line
    li $v0, 14                 
    move $a0, $s7              
    la $a1, buffer             
    li $a2, 100000      
    syscall

    # Initialize parsing variables
    la $t9, buffer 
    li $t0, 0
    
get_char:
    lb $t1, 0($t9)       
    beq $t1, ' ', skip_char    
    beq $t1, '\n', finish_read_first_line    
    beq $t1, '-', negative_detected_error 
    subi $t1, $t1, '0'         
    
    beq $t0, 0, get_N
    beq $t0, 1, get_M
    beq $t0, 2, get_p
    beq $t0, 3, get_s

skip_char:
    addi $t9, $t9, 1         
    j get_char

check_next_char:
    addi $t9, $t9, 1
    lb $t1, 0($t9)
    bne $t1, ' ', overflow_constrain_error
    j get_char
    
check_next_char_last:
    addi $t9, $t9, 1
    lb $t1, 0($t9)
    bne $t1, 0x0d, overflow_constrain_error
    j get_char	

get_N:    
    sw $t1, N
    blt $t1, 3, error_N_input_branch
    bgt $t1, 8, error_N_input_branch
    addi $t0, $t0, 1
    j check_next_char
    
error_N_input_branch:
    #Close input file
    li $v0, 16                       
    move $a0, $s7                    
    syscall        
    
    #Open output file
    li $v0, 13               
    la $a0, output_filename     
    li $a1, 1                  
    syscall
    move $t0, $v0

    # Write error to the file
    li $v0, 15             
    move $a0, $t0          
    la $a1, not_constrain_error_message      
    li $a2, 34             
    syscall

    # Close output file
    li $v0, 16             
    move $a0, $t0
    syscall
    
    li $v0, 10       
    syscall
    
get_M:
    sw $t1, M
    blt $t1, 2, error_M_input_branch
    bgt $t1, 4, error_M_input_branch
    addi $t0, $t0, 1
    j check_next_char

error_M_input_branch:
    li $v0, 16                       
    move $a0, $s7                   
    syscall        
    
    li $v0, 13               
    la $a0, output_filename     
    li $a1, 1                  
    syscall
    move $t0, $v0

    li $v0, 15             
    move $a0, $t0          
    la $a1, not_constrain_error_message      
    li $a2, 34       
    syscall

    li $v0, 16             
    move $a0, $t0          
    syscall
    
    li $v0, 10       
    syscall  

get_p:
    sw $t1, p
    blt $t1, 0, error_p_input_branch
    bgt $t1, 4, error_p_input_branch
    addi $t0, $t0, 1
    j check_next_char

error_p_input_branch:
    li $v0, 16                       
    move $a0, $s7                    
    syscall        
    
    li $v0, 13               
    la $a0, output_filename     
    li $a1, 1                  
    syscall
    move $t0, $v0

    li $v0, 15            
    move $a0, $t0          
    la $a1, not_constrain_error_message      
    li $a2, 34             
    syscall

    li $v0, 16             
    move $a0, $t0       
    syscall
    
    li $v0, 10       
    syscall  
    
get_s:
    sw $t1, s
    blt $t1, 1, error_s_input_branch
    bgt $t1, 3, error_s_input_branch
    addi $t0, $t0, 1
    j check_next_char_last

error_s_input_branch:
    li $v0, 16                       
    move $a0, $s7                    
    syscall        
    
    li $v0, 13               
    la $a0, output_filename     
    li $a1, 1                  
    syscall
    move $t0, $v0

    li $v0, 15             
    move $a0, $t0          
    la $a1, not_constrain_error_message      
    li $a2, 34             
    syscall

    li $v0, 16             
    move $a0, $t0    
    syscall
    
    li $v0, 10       
    syscall

finish_read_first_line:
    li $t0,0

#Load initial value
#calculate padded_size (image with 0-ring), out_size (N + 2P - M)/S + 1 (if out_size <= 0 throw error kernel bigger than image)
lw $s0, N
lw $s1, M
lw $s2, p
lw $s3, s

#Read data of image:
# Initialize parsing variables, use to read decimal from input file
li $t2, 0  # int part
li $t3, 0  # frac part
li $t4, 0  # flag 0 for int and 1 for frac
li $t5, 0  # fractional digit count
li $s6, 10 # constant 10
li $t7, 0  # sign flag (0 for positive, 1 for negative)
la $a2, image # base address for the image matrix
li $t8, 0  # offset calculation
mtc1 $s6, $f4
cvt.s.w $f4, $f4  # Convert integer 10 to floating-point 10.0

# Read image data into the image matrix
li $t6, 0 # i = 0
read_image_row:
    beq $t6, $s0, pad_image  # If i = N, jump to padding image process
    li $t0, 0 # j = 0

read_image_col:
    beq $t0, $s0, incre_image_row # If j = N, move to next row
    # Compute address in image matrix
    mul $t8, $t6, $s0    # i * N
    add $t8, $t8, $t0    # i * N + j
    sll $t8, $t8, 2      
    add $a3, $a2, $t8    # address of image[i][j]

    # Store float to image
    jal float_converted
    lwc1 $f12, 0($a3)
    addi $t0, $t0, 1
    j read_image_col

incre_image_row:
    addi $t6, $t6, 1
    j read_image_row

# Padding the image matrix to create the padded_image matrix
pad_image:
    la $t1, padded_image   # Base address of padded_image
    li $t6, 0              # i = 0
    # Get size of padded_image matrix
    add $t0, $s2, $s2
    add $t0, $t0, $s0
    sw $t0, padded_size
    lw $s4, padded_size

pad_image_row:
    beq $t6, $s0, read_filter  # If i = N, jump to read filter process
    li $t0, 0              # j = 0

pad_image_col:
    beq $t0, $s0, next_pad_image_row # If j = N, move to next row

    # Compute source address in image matrix
    mul $t8, $t6, $s0      # i * N
    add $t8, $t8, $t0      # i * N + j
    sll $t8, $t8, 2 
    add $t2, $a2, $t8      # address of image[i][j]

    # Compute destination address in padded_image
    add $t6, $t6, $s2     # i + p
    add $t0, $t0, $s2     # j + p
    mul $t8, $t6, $s4     # (i + p) * padded_size
    add $t8, $t8, $t0     # (i + p) * padded_size + (j + p)
    sll $t8, $t8, 2  
    add $t3, $t1, $t8     # address of padded_image[i + p][j + p]
    sub $t6, $t6, $s2     # Reset i
    sub $t0, $t0, $s2     # Reset j
    # Load value from image[i][j] into padded_image[i + p][j + p]
    lwc1 $f0, 0($t2)
    swc1 $f0, 0($t3)

    addi $t0, $t0, 1        # j++
    j pad_image_col

next_pad_image_row:
    addi $t6, $t6, 1        # i++
    j pad_image_row


#read filter:
read_filter:
    li $t2, 0
    li $t3, 0  
    la $a2, kernel
    addi $t9, $t9, 1
    li $t6, 0 # i = 0

read_filter_row:
    beq $t6, $s1, preconvo # If i = M, jump to convolution operation process
    li $t0, 0 # j = 0

read_filter_col:
    beq $t0, $s1, incre_filter_row # If j = M, move to next row

    mul $t8, $t6, $s1 # i * M
    add $t8, $t8, $t0 # i * M + j
    sll $t8, $t8, 2
    add $a3, $t8, $a2 # address of kernel[i][j]

    #store float to filter
    jal float_converted

    addi $t0, $t0, 1
    j read_filter_col

incre_filter_row:
    addi $t6, $t6, 1
    j read_filter_row

#string to float:
float_converted:
    addi $t9, $t9, 1
    lb $t1, 0($t9)
    beq $t1, 0x00, switch_to_integer
    beq $t1, 0x0d, switch_to_integer
    beq $t1, '.', switch_to_fraction
    beq $t1, ' ', switch_to_integer
    beq $t1, '-', set_neg
    subi $t1, $t1, '0'
    beq $t4, 0, integer
    beq $t4, 1, fraction

#set negative:
set_neg:
    li $t7, 1
    j float_converted

#read integer part
integer:
    mul $t2, $t2, $s6
    add $t2, $t2, $t1
    j float_converted

#read float part
fraction:
    mul $t3, $t3, $s6
    add $t3, $t3, $t1
    addi $t5, $t5, 1
    j float_converted

#switch
switch_to_fraction:
    li $t4, 1
    j float_converted

switch_to_integer:
    li $t4, 0
    j combine

#combine integer and fraction part
combine:
    mtc1 $t2, $f0                  # Move integer part to floating-point register $f0
    cvt.s.w $f0, $f0                # Convert integer in $f0 to float
    mtc1 $t3, $f2                  # Move fractional part to floating-point register $f2
    cvt.s.w $f2, $f2                # Convert integer in $f2 to float
adjust_fraction:
    beq $t5, 0, done_fraction_adjustment
    div.s $f2, $f2, $f4            # Divide fractional part by 10
    addi $t5, $t5, -1              # Decrease the fractional counter
    j adjust_fraction

done_fraction_adjustment:
    add.s $f0, $f0, $f2            # Combine integer and fractional part
    
    beq $t7, 0, skip_neg
    neg.s $f0, $f0                 # Negate the float if negative
    
skip_neg:
    li $t2, 0
    li $t3, 0
    li $t7, 0
    swc1 $f0, 0($a3)
    lwc1 $f12, 0($a3) 
    jr $ra

preconvo:
    # Size of output
    li $t0,0
    sub $t0, $s4, $s1
    blez $t0,kernel_image_error
    div $t0, $s3
    mflo $t0
    addi $t0, $t0, 1
    sw $t0, out_size
    lw $s5, out_size

    #reset var
    li $t2, 0 # r
    li $t3, 0 # c
    li $s6, 0 # i
    li $t7, 0 # j
    li $t8, 0
    la $a2, padded_image
    la $a3, kernel
convolution:
    li $t2, 0       # r = 0
loop_r:
    bge $t2, $s5, end_convolution
    li $t3, 0       # c = 0
loop_c:
    bge $t3, $s5, next_r
    mtc1 $zero, $f0        # sum = 0.0
    li $t4, 0              # i = 0
loop_i:
    bge $t4, $s1, get_sum   # if i >= M, store sum
    li $t5, 0              # j = 0
loop_j:
    bge $t5, $s1, next_i   # if j >= M, increase i
    # padded_image index
    mul $t6, $t2, $s3      # r * s
    add $t6, $t6, $t4      # r * s + i
    mul $t7, $t3, $s3      # c * s
    add $t7, $t7, $t5      # c * s + j
    # address in padded_image
    mul $t8, $t6, $s4      # (r * s + i) * padded_size
    add $t8, $t8, $t7      # (r * s + i) * padded_size + (c * s + j)
    sll $t8, $t8, 2
    la $t9, padded_image
    add $t9, $t9, $t8      # Address of padded_image element
    lwc1 $f2, 0($t9)       # Load padded_image element into $f2
    # address in kernel
    mul $t8, $t4, $s1      # i * M
    add $t8, $t8, $t5      # i * M + j
    sll $t8, $t8, 2
    la $t9, kernel
    add $t9, $t9, $t8      # Address of kernel element
    lwc1 $f4, 0($t9)       # Load kernel element into $f4
    mul.s $f6, $f2, $f4
    add.s $f0, $f0, $f6
    addi $t5, $t5, 1       # j++
    j loop_j
next_i:
    addi $t4, $t4, 1       # i++
    j loop_i
get_sum:
    mul $t8, $t2, $s5      # r * out_size
    add $t8, $t8, $t3      # r * out_size + c
    sll $t8, $t8, 2        
    la $t9, out
    add $t9, $t9, $t8
    swc1 $f0, 0($t9)       # Store sum
    addi $t3, $t3, 1       # c++
    j loop_c
next_r:
    addi $t2, $t2, 1       # r++
    j loop_r
end_convolution:
    # Open output file
    li $v0, 13                 
    la $a0, output_filename    
    li $a1, 1                  
    syscall
    move $s1, $v0

    # Write output matrix to the file
    li $t2, 0       # r = 0
print_loop_r:
    beq $t2, $s5, end_write_output   # if r >= out_size, exit
    li $t3, 0       # c = 0
print_loop_c:
    beq $t3, $s5, next_print_r       # if c >= out_size, increment r

    # Load out[r * out_size + c]
    mul $t8, $t2, $s5                # r * out_size
    add $t8, $t8, $t3                # r * out_size + c
    sll $t8, $t8, 2 
    la $t9, out
    add $t9, $t9, $t8
    lwc1 $f12, 0($t9)                # Load element into $f12

    # Convert float to string
    jal float_to_string

    # Find the length of the string
    la $t0, float_string_buffer
    move $t1, $t0                    # $t1 is used to traverse the string
    li $t4, 0                        # Initialize length to 0
count_string_length:
    lb $t5, 0($t1)
    beq $t5, $zero, done_counting_string_length
    addi $t4, $t4, 1
    addi $t1, $t1, 1
    j count_string_length
done_counting_string_length:
    # Write the string to the file
    move $a0, $s1                    
    la $a1, float_string_buffer      
    move $a2, $t4                    
    li $v0, 15                  
    syscall

    # Write a space character
    move $a0, $s1                    
    la $a1, space_char                 
    li $a2, 1                        
    li $v0, 15                   
    syscall

    addi $t3, $t3, 1                 # c++
    j print_loop_c
next_print_r:
    addi $t2, $t2, 1                 # r++
    j print_loop_r

end_write_output:
    # Close the output file
    li $v0, 16                       
    move $a0, $s1                    
    syscall

    # Close the input file
    li $v0, 16                       
    move $a0, $s7                    
    syscall

    # Exit
    li $v0, 10                    
    syscall

float_to_string:
    # Save registers
    addi $sp, $sp, -40
    sw $ra, 36($sp)
    sw $t0, 32($sp)
    sw $t1, 28($sp)
    sw $t2, 24($sp)
    sw $t3, 20($sp)
    sw $t4, 16($sp)
    sw $t5, 12($sp)
    sw $t6, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)

    # Clear buffer
    la $t2, float_string_buffer
    li $t3, 64  # Buffer size
clear_buffer_loop:
    beqz $t3, buffer_cleared
    sb $zero, 0($t2)
    addi $t2, $t2, 1
    subi $t3, $t3, 1
    j clear_buffer_loop
buffer_cleared:
    # Reset buffer pointer
    la $t2, float_string_buffer

    # Handle negative numbers
    li $t0, 0                  # Negative flag
    mtc1 $zero, $f2            # Load 0.0 into $f2
    c.lt.s $f12, $f2           # Compare number with 0.0
    bc1f positive_number
    li $t0, 1                  # If the number is negative, change flag 
    neg.s $f12, $f12           # Make the number positive
positive_number:
    # Extract integer part
    trunc.w.s $f0, $f12   
    mfc1 $t1, $f0              # Move integer part to $t1

    # Extract fractional part
    cvt.s.w $f0, $f0           # Convert integer part back to float
    sub.s $f1, $f12, $f0   

    # Convert integer part to string
    move $a0, $t1              
    move $a1, $t2              
    jal int_to_string          
    move $t2, $v0       

    # Add negative sign if needed
    beq $t0, $zero, skip_neg_sign
    # Shift string right to make space for '-'
    la $t4, float_string_buffer  
    move $t3, $t2              
    subi $t3, $t3, 1           # Adjust $t3 to point to the last character
shift_neg_loop:
    blt $t3, $t4, shift_neg_done
    lb $t5, 0($t3)
    sb $t5, 1($t3)
    subi $t3, $t3, 1
    j shift_neg_loop
shift_neg_done:
    li $t5, '-'
    sb $t5, 0($t4)
    addi $t2, $t2, 1       
skip_neg_sign:
    # Add decimal point
    li $t5, '.'
    sb $t5, 0($t2)
    addi $t2, $t2, 1

    # Convert fractional part to integer
    l.s $f2, float_thousand          # Multiplier for 4 decimal places
    mul.s $f1, $f1, $f2        # Multiply fractional part
    trunc.w.s $f1, $f1         # Convert to integer
    mfc1 $t1, $f1              

    # Pad fractional part with leading zeros if necessary
    move $t5, $t1              
    li $s0, 4                  # Number of decimal places

    # Count the number of digits in the fractional integer
count_leading_zeros:
    move $s1, $zero            
    move $t9, $t5        

    # If the fractional part is zero, output zeros directly
    beq $t9, $zero, fractional_zero

count_digits_loop:
    div $t9, $t9, 10
    mflo $t9
    addi $s1, $s1, 1
    bnez $t9, count_digits_loop

calculate_padding:
    # Calculate the number of leading zeros needed
    sub $t6, $s0, $s1     
    blez $t6, skip_padding

padding_loop:
    li $t7, '0'
    sb $t7, 0($t2)
    addi $t2, $t2, 1
    subi $t6, $t6, 1
    bgtz $t6, padding_loop

skip_padding:
    # Convert the fractional integer to string
    move $a0, $t1              
    move $a1, $t2             
    jal int_to_string          
    move $t2, $v0           
    j finalize_string

fractional_zero:
    # Fractional part is zero; output the required number of zeros directly
    move $t6, $s0             
fractional_zero_loop:
    li $t7, '0'
    sb $t7, 0($t2)
    addi $t2, $t2, 1
    subi $t6, $t6, 1
    bgtz $t6, fractional_zero_loop

finalize_string:
    # Null-terminate the string
    li $t3, 0
    sb $t3, 0($t2)

    # Restore registers
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $t6, 8($sp)
    lw $t5, 12($sp)
    lw $t4, 16($sp)
    lw $t3, 20($sp)
    lw $t2, 24($sp)
    lw $t1, 28($sp)
    lw $t0, 32($sp)
    lw $ra, 36($sp)
    addi $sp, $sp, 40
    jr $ra

# Converts integer in $a0 to string, stores at $a1
int_to_string:
    # Check if zero
    beq $a0, $zero, int_zero
    # Save registers
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $t1, 8($sp)
    sw $t2, 4($sp)
    sw $t3, 0($sp)

    # Initialize variables
    move $t1, $a0
    la $t2, int_temp_buffer

int_to_string_loop:
    li $t3, 10
    div $t1, $t3
    mfhi $t4                
    mflo $t1                 
    addi $t4, $t4, '0'       
    sb $t4, 0($t2)
    addi $t2, $t2, 1
    bne $t1, $zero, int_to_string_loop

    # Reverse the string
    subi $t2, $t2, 1         # Adjust pointer
    la $t5, int_temp_buffer
reverse_loop:
    blt $t2, $t5, reverse_done
    lb $t6, 0($t2)
    sb $t6, 0($a1)
    addi $a1, $a1, 1
    subi $t2, $t2, 1
    j reverse_loop
reverse_done:
    # Restore registers and return
    lw $t3, 0($sp)
    lw $t2, 4($sp)
    lw $t1, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    move $v0, $a1
    jr $ra

int_zero:
    li $t4, '0'
    sb $t4, 0($a1)
    addi $a1, $a1, 1
    move $v0, $a1
    jr $ra

negative_detected_error:
    li $v0, 16                       
    move $a0, $s7                   
    syscall        
    
    li $v0, 13               
    la $a0, output_filename     
    li $a1, 1                  
    syscall
    move $t0, $v0

    li $v0, 15            
    move $a0, $t0          
    la $a1, not_constrain_error_message      
    li $a2, 24             
    syscall

    li $v0, 16            
    move $a0, $t0          
    syscall
    
    li $v0, 10       
    syscall

kernel_image_error:
    li $v0, 16                       
    move $a0, $s7                    
    syscall        
    
    li $v0, 13               
    la $a0, output_filename     
    li $a1, 1                  
    syscall
    move $t0, $v0

    li $v0, 15             
    move $a0, $t0          
    la $a1, kernel_image_error_message      
    li $a2, 31             
    syscall

    li $v0, 16            
    move $a0, $t0          
    syscall
    
    li $v0, 10       
    syscall
    
overflow_constrain_error:
    li $v0, 16                       
    move $a0, $s7                    
    syscall        
    
    li $v0, 13               
    la $a0, output_filename     
    li $a1, 1                  
    syscall
    move $t0, $v0

    li $v0, 15             
    move $a0, $t0          
    la $a1, not_constrain_error_message      
    li $a2, 34             
    syscall

    li $v0, 16             
    move $a0, $t0        
    syscall
    
    li $v0, 10       
    syscall
