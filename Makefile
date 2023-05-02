# Created from https://github.com/davisjp1822/stm32_nucleo_linux

CC=arm-none-eabi-gcc
AR=ar
OPENOCD=openocd
OBJCOPY=objcopy
SCREEN=screen

LIBDIR=./lib

LINKER_FILE=linker/STM32F401VEHx_FLASH.ld

LD_FLAGS=-L${LIBDIR}		\
	  -lstm32f4xxbsp	\
	  -lstm32f4xxhal	\
          -Wl,--gc-sections

CFLAGS=-Wall		\
	-mcpu=cortex-m4 \
	-mlittle-endian \
	-mthumb		\
	-O3		\
	-DSTM32F401xE   \
	-DNUCLEO

INCLUDES=-I./inc							\
	  -I./ciphers/arch                                                \
	  -I./STM32Cube_FW/Drivers/CMSIS/Device/ST/STM32F4xx/Include	\
	  -I./STM32Cube_FW/Drivers/CMSIS/Include			\
	  -I./STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo			\
	  -I./STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Inc

################################################################
# Global setup

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<
%.o: %.s
	$(CC) $(CFLAGS) $(INCLUDES) -c -o $@ $<

.PRECIOUS: %.o

################################################################
# HAL library

HAL_LIB_FILES = $(wildcard STM32Cube_FW/Drivers/STM32F4xx_HAL_Driver/Src/*.c)
HAL_LIB_OBJS = $(patsubst %.c,%.o, $(HAL_LIB_FILES))

lib/libstm32f4xxhal.a: $(HAL_LIB_OBJS)
	$(AR) rcs $@ $^

################################################################
# BSP library

BSP_LIB_FILES = $(wildcard STM32Cube_FW/Drivers/BSP/STM32F4xx-Nucleo/*.c)
BSP_LIB_OBJS = $(patsubst %.c,%.o, $(BSP_LIB_FILES))

lib/libstm32f4xxbsp.a: $(BSP_LIB_OBJS)
	$(AR) rcs $@ $^

################################################################
# Benchmarks

SRC_FILES = $(wildcard src/*.c src/*.s)
SRC_OBJS = $(patsubst %.s,%.o, $(patsubst %.c,%.o, $(SRC_FILES)))

%.hex: %.elf
	objcopy -Oihex $*.elf $*.hex

# TODO: more ciphers to come:
CIPHERS=ciphers/pyjamask.c
CIPHERS_OBJS=$(CIPHERS:.c=.elf)

all: ciphers/pyjamask.elf

%.elf: %.o $(SRC_OBJS) lib/libstm32f4xxhal.a lib/libstm32f4xxbsp.a
	$(CC) $(CFLAGS) -T$(LINKER_FILE) $<					\
		src/stm32f4xx_it.o 			\
		src/syscalls.o src/system_stm32f4xx.o				\
		src/startup_stm32f401xe.o src/main.o				\
		 -o $@ $(LD_FLAGS)

################################################################
# Cleaning

clean:
	rm -f lib/libstm32f4xxhal.a		\
	      lib/libstm32f4xxbsp.a		\
	      $(BSP_LIB_OBJS) $(HAL_LIB_OBJS)	\
	      $(SRC_OBJS)			\
	      $(CIPHERS_OBJS)			\

clean-all:
	make clean

################################################################
# Interactions with the board

# Restart the board
reboot:
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset; exit"

# Load .hex file to the board
%.upload: %.hex
	sudo $(OPENOCD) -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg \
	                -c "init; reset halt; flash write_image erase $<; reset run; exit"

# Save serial input to the given file
%.log: %.hex force
	./bin/serial.sh $*.elf $< $@

force:
	true
