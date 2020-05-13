SETLOCAL EnableDelayedExpansion

REM Libraries to link in
SET libraries=-lc -lkernel

REM Read the script arguments into local vars
SET intdir=%1
SET targetname=%~2
SET outputPath=%~3

SET outputElf=%intdir%%targetname%.elf
SET outputOelf=%intdir%%targetname%.oelf
SET outputPrx=%intdir%%targetname%.prx
SET outputStub=%intdir%%targetname%_stub.so

REM Compile object files for all the source files
FOR %%f in (..\*.c) DO (
    ECHO Compiling %%~f...
    clang   -cc1 -triple x86_64-scei-ps4-elf -munwind-tables -I"%OO_PS4_TOOLCHAIN%\include" -emit-obj -o %intdir%\%%~nf.o "%%~f"
)
FOR %%f in (..\*.cpp) DO (
    ECHO Compiling %%~f...
    clang++ -cc1 -triple x86_64-scei-ps4-elf -munwind-tables -I"%OO_PS4_TOOLCHAIN%\include" -emit-obj -o %intdir%\%%~nf.o "%%~f"
)

REM Get a list of object files for linking
SET obj_files=
FOR %%f IN (%intdir%\\*.o) DO SET obj_files=!obj_files! .\%%f

REM Link the input ELF
ECHO Linking...
ld.lld -m elf_x86_64 -pie --version-script="%targetname%.version" --script "%OO_PS4_TOOLCHAIN%\link.x" --eh-frame-hdr -o "%outputElf%" "-L%OO_PS4_TOOLCHAIN%\lib" -lc -lkernel --verbose "%OO_PS4_TOOLCHAIN%\lib\crtlib.o" %obj_files%

REM Create stub shared libraries
FOR %%f in (..\*.c) DO (
    clang -target x86_64-pc-linux-gnu -ffreestanding -nostdlib -fno-builtin -fPIC -c -I"%OO_PS4_TOOLCHAIN%\include" -o %intdir%\%%~nf.o.stub "%%~f"
)
FOR %%f in (..\*.cpp) DO (
    clang++ -target x86_64-pc-linux-gnu -ffreestanding -nostdlib -fno-builtin -fPIC -c -I"%OO_PS4_TOOLCHAIN%\include" -o %intdir%\%%~nf.o.stub "%%~f"
)

SET stub_obj_files=
FOR %%f in (%intdir%\\*.o.stub) DO SET stub_obj_files=!stub_obj_files! .\%%f

clang++ -target x86_64-pc-linux-gnu -shared -fuse-ld=lld -ffreestanding -nostdlib -fno-builtin "-L%OO_PS4_TOOLCHAIN%\lib" %libraries% %stub_obj_files% -o "%outputStub%"

REM Create the prx
%OO_PS4_TOOLCHAIN%\bin\windows\create-lib.exe -in "%outputElf%" --out "%outputOelf%" --paid 0x3800000000000011

REM Cleanup
COPY "%outputPrx%" "%outputPath%\%targetname%.prx"
DEL "%outputPrx%"
