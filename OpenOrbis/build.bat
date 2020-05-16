SETLOCAL EnableDelayedExpansion

SET TOOLCHAIN=%OO_PS4_TOOLCHAIN%

SET LIBS=-lkernel

REM Compiler options. You likely won't need to touch these.
SET CC=clang
SET CXX=clang++
SET LD=ld.lld

SET TARGET=%~2

SET ODIR=%1
SET SDIR=%~3

REM Trim trailing \'s
IF %TOOLCHAIN:~-1%==\ SET TOOLCHAIN=%TOOLCHAIN:~0,-1%
IF      %ODIR:~-1%==\ SET ODIR=%ODIR:~0,-1%
IF      %SDIR:~-1%==\ SET SDIR=%SDIR:~0,-1%

SET IDIRS="-I%TOOLCHAIN%\include"
SET LDIRS="-L%TOOLCHAIN%\lib"

SET CFLAGS=-cc1 -triple x86_64-scei-ps4-elf -munwind-tables %IDIRS% -emit-obj
SET CXXFLAGS=%CFLAGS%
SET LFLAGS=-m elf_x86_64 --version-script="%SDIR%\%TARGET%.version" --script "%TOOLCHAIN%\link.x" --eh-frame-hdr %LDIRS% %LIBS% --verbose "%TOOLCHAIN%\lib\crtlib.o"

SET STUBCFLAGS=-target x86_64-pc-linux-gnu -ffreestanding -nostdlib -fno-builtin -fPIC -c %IDIRS%
SET STUBCXXFLAGS=%STUBCFLAGS%
SET STUBLFLAGS=-target x86_64-pc-linux-gnu -shared -fuse-ld=lld -ffreestanding -nostdlib -fno-builtin %LDIRS% %LIBS%

REM Make!

FOR %%f in (..\*.c) DO (
    ECHO Compiling %%~f...
    %CC% %CFLAGS% -o %ODIR%\%%~nf.o "%%~f"
)
FOR %%f in (..\*.cpp) DO (
    ECHO Compiling %%~f...
    %CXX% %CXXFLAGS% -o %ODIR%\%%~nf.o "%%~f"
)

REM Get a list of object files for linking
SET OBJS=
FOR %%f IN (%ODIR%\*.o) DO SET OBJS=!OBJS! %%f

REM Link the input ELF
ECHO Linking...
%LD% %OBJS% -o "%ODIR%\%TARGET%.elf" %LFLAGS%

REM Create stub shared libraries
FOR %%f in (..\*.c) DO (
    %CC% %STUBCFLAGS% -o %ODIR%\%%~nf.o.stub "%%~f"
)
FOR %%f in (..\*.cpp) DO (
    %CXX% %STUBCXXFLAGS% -o %ODIR%\%%~nf.o.stub "%%~f"
)

SET STUBOBJS=
FOR %%f in (%ODIR%\*.o.stub) DO SET STUBOBJS=!STUBOBJS! .\%%f

%CC% %STUBOBJS% -o "%ODIR%\%TARGET%_stub.so" %STUBLFLAGS%

REM Create the prx
ECHO Creating OELF/PRX...
%TOOLCHAIN%\bin\windows\create-lib.exe -libname sceGameRight -in "%ODIR%\%TARGET%.elf" -out "%ODIR%\%TARGET%.oelf"

REM Cleanup
COPY "%ODIR%\%TARGET%.prx" "%SDIR%\%TARGET%.prx"
DEL "%ODIR%\%TARGET%.prx"
