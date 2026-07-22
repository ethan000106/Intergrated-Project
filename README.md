
<div align="center">

# 🛠️ Vivado Integrated SoC System Design

![Tool](https://img.shields.io/badge/EDA-AMD_Vivado-red?style=for-the-badge&logo=Xilinx)
![Language](https://img.shields.io/badge/Language-SystemVerilog%20%2F%20Verilog-blue?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**AMD Xilinx Vivado 기반 RISC-V 코어 및 주변장치(Peripherals) 통합 시스템 설계 & FPGA 검증 프로젝트**

</div>

---

## ✨ Project Overview

본 프로젝트는 Vivado IDE 환경에서 **RISC-V 프로세서 코어, 메모리 서브시스템 및 주변장치(Peripherals)**를 통합(Integration)하여 FPGA 타겟 하드웨어 시스템으로 종합 검증 및 합성(Synthesis)이 가능하도록 구축된 하드웨어 설계 프로젝트입니다.

---

## 💡 Key Features

| 특징 (Feature) | 설명 (Description) |
| :--- | :--- |
| 🏗️ **Integrated SoC Architecture** | 코어, 메모리, I/O 주변장치가 하나의 Top-level 시스템으로 통합된 아키텍처 |
| ⚡ **Vivado Project Native** | AMD Xilinx Vivado 툴과의 완벽한 호환성 (`.xpr` 프로젝트 파일 제공) |
| 🎯 **FPGA Synthesis Ready** | Timing Constraints 및 Pin Placement 설정을 통한 실제 FPGA 보드 타겟 합성 가능 |
| 🔍 **System Level Verification** | Vivado Simulator (XSIM) 기반 통합 Testbench 시뮬레이션 환경 구축 |

---

## 📂 Directory Structure

```text
📦 Intergrated-Project
 ┣ 📂 Integrated Project.srcs      # RTL 소스코드, 구동 제약조건(XDC), Testbench
 ┃ ┣ 📂 sources_1                 # Design RTL Sources (.sv / .v)
 ┃ ┣ 📂 sim_1                     # Testbench Simulation Files
 ┃ ┗ 📂 Directory                 # Constraints & Configuration Files
 ┣ 📜 Integrated Project.xpr       # AMD Vivado Project File
 ┣ 📜 .gitignore                   # Vivado 임시/빌드 정크 파일 필터
 ┗ 📜 README.md                    # 프로젝트 종합 안내 문서
```

---

## 🛠️ How to Run in Vivado

### 1️⃣ Vivado GUI 모드로 프로젝트 열기
1. **AMD Vivado IDE**를 실행합니다.
2. `Open Project`를 클릭하고 `Integrated Project.xpr` 파일 선택
3. Flow Navigator에서 **Run Simulation** 또는 **Run Synthesis** 클릭

### 2️⃣ Vivado Tcl / Batch 모드로 시뮬레이션 실행 (CUI)
```bash
# XSIM 컴파일 및 시뮬레이션 예시
xvlog -sv -i Integrated\ Project.srcs/sources_1/new/*.sv
xelab tb_top -s tb_top_sim -debug typical
xsim tb_top_sim -gui
```

---

## 👨‍💻 Author

- **GitHub**: [@ethan000106](https://github.com/ethan000106)
- **License**: MIT License
```
