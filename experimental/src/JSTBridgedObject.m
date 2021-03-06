//
//  JSTBridgedObject.m
//  JSCocoa
//
//  Created by Patrick Geiller on 09/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "JSTBridgedObject.h"
#import "JSCocoaController.h"

@implementation JSTBridgedObject

@synthesize type;
@synthesize xml;
@synthesize declaredType;
@synthesize methodName;
@synthesize structureName;
@synthesize isAutoCall;
@synthesize runtimeInfo=_runtimeInfo;
@synthesize runtimeType=_runtimeType;


- (id)init {
	self = [super init];
	if (self != nil) {
        retainObject = YES;
        [JSCocoaController upJSTBridgedObjectCount];
	}
	return self;
}

- (id)initWithRuntimeInfo:(JSTRuntimeInfo*)rinfo {
    
	self = [self init];
	if (self != nil) {
        [self setRuntimeInfo:rinfo];
	}
    
	return self;
}


- (void)cleanUp {
    // WAIT WHAT?  CLASS METHOD FOR THIS?
    [JSCocoaController downJSTBridgedObjectCount];
    
    if (object && retainObject) {
        [JSCocoaController downBoxedJSObjectCount:object];
        [object release];
    }
    
    if (jsValue) {
        if (!externalJSValueIndex) {
            JSValueUnprotect(ctx, jsValue);
        }
        
        [JSCocoaController downJSValueProtectCount];
        
        // If holding a value from an external context, remove it from the GC-safe hash and release context.
        if (externalJSValueIndex) {
            JSStringRef scriptJS    = JSStringCreateWithUTF8CString("delete __gcprotect[arguments[0]]");
            JSObjectRef fn          = JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
            JSStringRelease(scriptJS);
            JSValueRef jsNumber     = JSValueMakeNumber(ctx, externalJSValueIndex);
            JSValueRef exception    = NULL;
            JSObjectCallAsFunction(ctx, fn, NULL, 1, (JSValueRef*)&jsNumber, &exception);
            
            if (exception) {
                NSLog(@"Got an exception while trying to release externalJSValueRef %p of context %p", jsValue, ctx);
            }
        }
    }
/*
    if (retainContext)
    {
        NSLog(@"releasing %x", ctx);
        JSContextGroupRelease(contextGroup);
//        JSGlobalContextRelease((JSGlobalContextRef)ctx);
    }
*/    
    // Release properties
    [type release];
    [xml release];
    [methodName release];
    [structureName release];
    [declaredType release];
    [_runtimeInfo release];
    [_runtimeType release];

}

- (void)dealloc {
    [self cleanUp];
    [super dealloc];
}

- (void)finalize {
    [self cleanUp];
    [super finalize];
}

- (void)setObject:(id)o {
    object = o;
    
    if (o) {
        [self setRuntimeType:@"@"];
    }
    
    if (object && [object retainCount] == -1) {
        return;
    } 
    
    [object retain];
}

- (void)setObjectNoRetain:(id)o {
    object          = o;
    retainObject    = NO;
}

- (BOOL)retainObject {
    return retainObject;
}


- (id)object {
    return object;
}

- (void)setMethod:(Method)m {
    method = m;
}

- (Method)method {
    return method;
}

- (void)setJSValueRef:(JSValueRef)v ctx:(JSContextRef)c
{
    // While autocalling we'll get a NULL value when boxing a void return type - just skip JSValueProtect
    if (!v)    
    {
//        NSLog(@"setJSValueRef: NULL value");
        jsValue = 0;
        return;
    }
    jsValue = v;
//    ctx        = c;
    // Register global context (this would crash the launcher as JSValueUnprotect was called on a destroyed context)
    ctx        = [[JSCocoaController controllerFromContext:c] ctx];
    JSValueProtect(ctx, jsValue);
    [JSCocoaController upJSValueProtectCount];
}

- (JSValueRef)jsValueRef {
    return jsValue;
}

- (JSContextRef)ctx {
    return ctx;
}


- (void)setExternalJSValueRef:(JSValueRef)v ctx:(JSContextRef)c
{
    if (!v)    
    {
        jsValue = 0;
        return;
    }
    jsValue = v;
    ctx        = c;

    // Register value in a hash to protect it from GC. This sucks but JSValueProtect() fails.
    JSStringRef scriptJS = JSStringCreateWithUTF8CString("if (!('__gcprotect' in this)) { __gcprotect = {}; __gcprotectidx = 1; } __gcprotect[__gcprotectidx] = arguments[0]; return __gcprotectidx++ ");
    JSObjectRef fn = JSObjectMakeFunction(ctx, NULL, 0, NULL, scriptJS, NULL, 1, NULL);
    JSStringRelease(scriptJS);
    
    JSValueRef exception = NULL;
    JSValueRef result = JSObjectCallAsFunction(ctx, fn, NULL, 1, (JSValueRef*)&jsValue, &exception);
    if (exception)    return;

    // Use hash index as key, will be used to remove value from hash upon deletion.
    externalJSValueIndex = (unsigned int)JSValueToNumber(ctx, result, &exception);
    if (exception)    return;

//    JSGlobalContextRetain((JSGlobalContextRef)ctx);
    [JSCocoaController upJSValueProtectCount];
}


- (void*)rawPointer {
    return rawPointer;
}

- (void)setRawPointer:(void*)rp encoding:(id)encoding {
    rawPointer = rp;
    [declaredType release];
    declaredType = [encoding retain];
}

- (id)rawPointerEncoding {
    return declaredType;
}


- (NSString*)description {
    
    
    return [NSString stringWithFormat:@"%@ (%@)", [super description], [[self runtimeInfo] symbolName]];
    
    
    /*
    NSString *extra;
    
    if ([type isEqualToString:@"rawPointer"]) {
        extra = [NSString stringWithFormat:@" (%x) %@", rawPointer, declaredType];
    }
    else {
        extra = [object description];
    }
    
    return [NSString stringWithFormat:@"<%@: %x holding %@%@>",
                [self class], 
                self, 
                type,
                extra
                ];
    */
}

- (id)dereferencedObject {
    if (![type isEqualToString:@"rawPointer"] || !rawPointer) {
        return nil;
    }
    
    return *(void**)rawPointer;
}

- (BOOL)referenceObject:(id)o {
    if (![type isEqualToString:@"rawPointer"]) {
        return NO;
    }

    *(id*)rawPointer = o;
    
    return YES;
}


@end

