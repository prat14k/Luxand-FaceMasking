//
//  partially based on ColorTrackingGLView.m
//  from ColorTracking application
//  The source code for this application is available under a BSD license.
//
//  Created by Brad Larson on 10/7/2010.
//  Modified by Anton Malyshev on 03/01/2016.
//

#import "TrackingGLView.h"
#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>

@implementation TrackingGLView

#pragma mark -
#pragma mark Initialization and teardown

static int glerr = GL_NO_ERROR;


// Override the class method to return the OpenGL layer, as opposed to the normal CALayer
+ (Class) layerClass 
{
	return [CAEAGLLayer class];
}

- (EAGLContext *) context
{
    return context;
}

- (void)dealloc 
{
    [context release];
    context = NULL;
    [super dealloc];
}

- (id)initWithFrame:(CGRect)frame 
{
    if ((self = [super initWithFrame:frame])) {
		// Do OpenGL Core Animation layer setup
		CAEAGLLayer * eaglLayer = (CAEAGLLayer *)self.layer;
		
		// Set scaling to account for Retina display	
        //if ([self respondsToSelector:@selector(setContentScaleFactor:)]) {
        //    self.contentScaleFactor = [[UIScreen mainScreen] scale];
        //}
		
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		if (!context || ![EAGLContext setCurrentContext:context] || ![self createFramebuffers]) {
			[self release];
			return nil;
		}
        
        //self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        //self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

#pragma mark -
#pragma mark OpenGL drawing

- (BOOL)createFramebuffers
{	
    glDisable(GL_DEPTH_TEST);
    if ((glerr = glGetError())) NSLog(@"Error in glDisable, %d", glerr);
	
    // Onscreen framebuffer object
	glGenFramebuffersOES(1, &viewFramebuffer);
    if ((glerr = glGetError())) NSLog(@"Error in glGenFramebuffers, %d", glerr);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    if ((glerr = glGetError())) NSLog(@"Error in glBindFramebuffer, %d", glerr);
    
    glGenRenderbuffersOES(1, &viewRenderbuffer);
    if ((glerr = glGetError())) NSLog(@"Error in glGenRenderbuffers, %d", glerr);
    
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    if ((glerr = glGetError())) NSLog(@"Error in glBindRenderbuffer, %d", glerr);
    
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    if ((glerr = glGetError())) NSLog(@"Error in glGetRenderbufferParameteriv, %d", glerr);

    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    if ((glerr = glGetError())) NSLog(@"Error in glGetRenderbufferParameteriv, %d", glerr);

    NSLog(@"Backing width: %d, height: %d", backingWidth, backingHeight);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    if ((glerr = glGetError())) NSLog(@"Error in glFramebufferRenderbuffer, %d", glerr);
    
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"Failure with framebuffer generation");
		return NO;
	}
    if ((glerr = glGetError())) NSLog(@"Error in glCheckFramebufferStatus, %d", glerr);
	
	return YES;
}

- (void)destroyFramebuffer;
{	
	if (viewFramebuffer) {
		glDeleteFramebuffersOES(1, &viewFramebuffer);
        if ((glerr = glGetError())) NSLog(@"Error in glDeleteFramebuffers, %d", glerr);
        viewFramebuffer = 0;
	}
	if (viewRenderbuffer) {
		glDeleteRenderbuffersOES(1, &viewRenderbuffer);
        if ((glerr = glGetError())) NSLog(@"Error in glDeleteRenderbuffers, %d", glerr);
        viewRenderbuffer = 0;
    }
}

- (void)setDisplayFramebuffer;
{
    if (context) {
        //[EAGLContext setCurrentContext:context];
        if (!viewFramebuffer) {
            [self createFramebuffers];
		}
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
        if ((glerr = glGetError())) NSLog(@"Error in glBindFramebuffer, %d", glerr);
        glViewport(0, 0, backingWidth, backingHeight);
        if ((glerr = glGetError())) NSLog(@"Error in glViewport, %d", glerr);
    }
}

- (BOOL)presentFramebuffer;
{
    //Using GL_RENDERBUFFER_OES instead of GL_RENDERBUFFER for OpenGL ES 1.1
    BOOL success = FALSE;
    if (context) {
        //[EAGLContext setCurrentContext:context];        
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
        if ((glerr = glGetError())) NSLog(@"Error in glBindRenderbuffer, %d", glerr);
        success = [context presentRenderbuffer:GL_RENDERBUFFER_OES];
    }
    return success;
}

@end
