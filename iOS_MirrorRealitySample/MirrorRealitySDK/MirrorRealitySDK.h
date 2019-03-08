///////////////////////////////////////////////////
//
//     Luxand MirrorReality Library
//
//
//  Copyright(c) 2005-2016 Luxand, Inc.
//         http://www.luxand.com
//
///////////////////////////////////////////////////

#ifndef _LUXAND_MIRROR_REALITY_SDK_
#define _LUXAND_MIRROR_REALITY_SDK_

#if defined( _WIN32 ) || defined ( _WIN64 )
#include <gl/gl.h>
#include <gl/glu.h>
#else
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#endif

#include "LuxandFaceSDK.h"

#define MR_MAX_FACES 5

typedef struct {
    float x, y;
} TPointf;

typedef TPointf MR_MaskFeatures [FSDK_FACIAL_FEATURE_COUNT];

const int MR_MASK_TEXTURE_SIZE = 1024;

const int MR_SHIFT_TYPE_NO = 0;
const int MR_SHIFT_TYPE_OUT = 1;
const int MR_SHIFT_TYPE_IN = 2;


int MR_LoadMaskCoordsFromFile(const char * filename, MR_MaskFeatures maskCoords);

int MR_LoadMask(HImage maskImage1, HImage maskImage2, GLuint maskTexture1, GLuint maskTexture2, int * isTexture1Created, int * isTexture2Created);

int MR_DrawGLScene(GLuint facesTexture, int facesDetected, FSDK_Features features[MR_MAX_FACES], int rotationAngle90Multiplier, int shiftType, GLuint maskTexture1, GLuint maskTexture2, MR_MaskFeatures maskCoords, int isTexture1Created, int isTexture2Created, int width, int height);

int MR_ActivateLibrary(char * LicenseKey);


#endif
