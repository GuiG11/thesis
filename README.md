# MATLAB – Reverse Engineering of a Railway Terminal Protocol

Este repositório contém o código MATLAB desenvolvido no âmbito da dissertação de mestrado **"Modernização de um Terminal de Maquinista por Engenharia Reversa"**, realizada na Universidade de Aveiro, em colaboração com a CP - Comboios de Portugal.

## Objetivo

O programa foi desenvolvido para analisar capturas da comunicação série entre a Unidade Central de Comando (UCC) e o terminal de visualização original de um veículo ferroviário, com o objetivo de investigar a estrutura e o funcionamento do protocolo utilizado.

## Funcionalidades

- Leitura e visualização de sinais provenientes de ficheiros `.mat`.
- Descodificação UART a **4800 baud, 8N1**.
- Conversão dos dados recebidos para hexadecimal e ASCII.
- Análise da frequência de bytes e identificação de sequências repetidas.
- Comparação de padrões entre diferentes capturas.
- Identificação exploratória de comandos introduzidos pelo byte `ESC` (`0x1B`).

## Notas

Esta ferramenta foi desenvolvida para fins de investigação e engenharia reversa. A interpretação do protocolo é parcial e os resultados não constituem uma especificação completa do sistema original.

As capturas originais utilizadas no projeto não são disponibilizadas neste repositório.


*O código Arduino desenvolvido para a reprodução dos ecrãs do terminal original segundo a interpretação do protocolo permanece privado, não sendo disponibilizado neste repositório.
