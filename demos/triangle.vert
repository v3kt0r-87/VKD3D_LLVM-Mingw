#version 150
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec4 position_in;
layout(location = 1) in vec4 colour_in;

layout(location = 0) out vec4 colour_out;

void main(void)
{
    gl_Position = position_in;
    colour_out = colour_in;
}
