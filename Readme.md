# PBR Exercise

使用ShaderLab练习手写PBR Shading, 以加深对PBR的理解.

Shader文件位于`Assets/Shaders/`下

* 直接光(单光源):
  * 漫反射: Lambert
  * 镜面反射: Cook-Torrance
* 间接光:
  * 漫反射: Spherical Harmonics
  * 镜面反射: Split Sum, BRDF integration