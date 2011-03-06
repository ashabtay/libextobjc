//
//  EXTPrivateMethod.m
//  extobjc
//
//  Created by Justin Spahr-Summers on 2011-03-02.
//  Released into the public domain.
//

#import "EXTPrivateMethod.h"
#import "EXTRuntimeExtensions.h"
#import <string.h>

Class ext_privateMethodsClass_ = nil;
Protocol *ext_privateMethodsFakeProtocol_ = NULL;

static
id ext_removedMethodCalled (id self, SEL _cmd, ...) {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

BOOL ext_makeProtocolMethodsPrivate (Class targetClass, Protocol *protocol) {
	const char *className = class_getName(targetClass);

	Class superclass = class_getSuperclass(targetClass);
	if (!superclass) {
		fprintf(stderr, "ERROR: Cannot make methods on class %s private without a superclass\n", className);
		return NO;
	}

	unsigned methodCount = 0;
	struct objc_method_description *methods = protocol_copyMethodDescriptionList(
		protocol,
		YES,
		YES,
		&methodCount
	);

	BOOL success = YES;
	for (unsigned methodIndex = 0;methodIndex < methodCount;++methodIndex) {
		SEL name = methods[methodIndex].name;
		const char *selectorName = sel_getName(name);

		Method foundMethod = ext_getImmediateInstanceMethod(targetClass, name);
		if (!foundMethod) {
			fprintf(stderr, "ERROR: Method %s not found on class %s\n", selectorName, className);
			success = NO;
			continue;
		}

		Method originalMethod = ext_getImmediateInstanceMethod(superclass, name);
		if (originalMethod && method_getImplementation(originalMethod) != (IMP)&ext_removedMethodCalled) {
			fprintf(stderr, "ERROR: Method %s already exists on class %s\n", selectorName, class_getName(superclass));
			success = NO;
			continue;
		}
		
		class_replaceMethod(superclass, name, method_getImplementation(foundMethod), method_getTypeEncoding(foundMethod));
		method_setImplementation(foundMethod, (IMP)&ext_removedMethodCalled);
	//	ext_removeMethod(targetClass, name);
	}

	return success;
}

