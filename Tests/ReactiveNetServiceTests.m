//
//  ReactiveNetServiceTests.m
//  ReactiveNetService
//
//  Created by Chris Devereux on 29/07/2013.
//
//

#import <SenTestingKit/SenTestingKit.h>
#import "NSNetService+ReactiveNetService.h"

#define TIMEOUT HUGE_VAL

static void
_WaitUntil(id self, const char *stringified, BOOL(^condition)(void));

#define WaitUntil(...) _WaitUntil(self, #__VA_ARGS__, ^BOOL{ return __VA_ARGS__; })


@interface ReactiveNetServiceTests : SenTestCase <NSNetServiceDelegate> {
    NSNetService *_server;
    NSString *_type;
}

@end

@implementation ReactiveNetServiceTests

- (void)setUp
{
    [super setUp];
    
    // stops browser from finding any misc services on the local network
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString *protocolName = [CFBridgingRelease(CFUUIDCreateString(NULL, uuid)) stringByReplacingOccurrencesOfString:@"-" withString:@""];
    CFRelease(uuid);
    
    _type = [NSString stringWithFormat:@"_%@._tcp", protocolName];
    _server = [[NSNetService alloc] initWithDomain:@"local" type:_type name:@"Test Service" port:1234];
    _server.delegate = self;
    
    [_server publish];
}

- (void)tearDown
{
    [_server stop];
    _server.delegate = nil;
    _server = nil;
    
    [super tearDown];
}


#pragma mark -

- (void)testBrowsingForServices
{
    __block RACSequence *services;
    RACDisposable *disposable = [[NSNetService rac_servicesOfType:_type inDomain:@"local"] subscribeNext:^(id x) {
        services = x;
    }];
    
    @try {
        WaitUntil(services.array.count == 1);
        STAssertEqualObjects([services.head name], @"Test Service", nil);
        
        [_server stop];
        
        WaitUntil(services.array.count == 0);
    }
    @finally {
        [disposable dispose];
    }
}

- (void)testBrowsingForServicesWithAutomaticResolution
{
    __block RACSequence *services;
    RACDisposable *disposable = [[NSNetService rac_resolvedServicesOfType:_type inDomain:@"local"] subscribeNext:^(id x) {
        services = x;
    }];
    
    @try {
        WaitUntil(services.array.count == 1);
        STAssertEqualObjects([services.head name], @"Test Service", nil);
        STAssertNotNil([services.head hostName], nil);
        
        [_server stop];
        
        WaitUntil(services.array.count == 0);
    }
    @finally {
        [disposable dispose];
    }
}

- (void)testErrorWhileBrowsingForService
{
    __block NSError *error;
    RACDisposable *disposable = [[NSNetService rac_servicesOfType:@"invalidServiceName" inDomain:@"local"] subscribeNext:^(RACSequence *x) {
        STAssertNil(x.head, @"should not send services");
    } error:^(NSError *err) {
        error = err;
    }];
    
    @try {
        WaitUntil(error != nil);
        STAssertEqualObjects(error.domain, RACNetServiceErrorDomain, nil);
        STAssertEquals(error.code, (NSInteger)-72004, nil);
    }
    @finally {
        [disposable dispose];
    }
}

- (void)testResolvingServices
{
    NSNetService *service = [self waitForServiceWithName:@"Test Service"];
    __block NSNetService *resolved;
    
    RACDisposable *disposable = [[service rac_resolveWithTimeout:10] subscribeNext:^(NSNetService *x) {
        resolved = x;
    }];
    
    @try {
        WaitUntil(resolved != nil);
        
        STAssertEquals(resolved, service, nil);
        STAssertNotNil(resolved.hostName, nil);
    }
    @finally {
        [disposable dispose];
    }
    
}

- (void)testErrorWhileResolvingServices
{
    NSNetService *service = [self waitForServiceWithName:@"Test Service"];
    __block NSError *error;
    
    //HACK: need a better way to force service resolution to error
    RACDisposable *disposable = [[service rac_resolveWithTimeout:0.00001] subscribeNext:^(id x) {
        STFail(@"should not resolve");
    } error:^(NSError *err) {
        error = err;
    }];
    
    @try {
        WaitUntil(error != nil);
    }
    @finally {
        [disposable dispose];
    }
}


#pragma mark - Helpers:

- (NSNetService *)waitForServiceWithName:(NSString *)name
{
    __block NSArray *matchingServices;
    
    RACDisposable *disposable = [[NSNetService rac_servicesOfType:_type inDomain:@"local"] subscribeNext:^(RACSequence *x) {
        matchingServices = [[x filter:^BOOL(NSNetService *x) {
            return [x.name isEqualToString:name];
        }] array];
    }];
    
    @try {
        WaitUntil(matchingServices.count > 0);
    }
    @finally {
        [disposable dispose];
    }
    
    return matchingServices.lastObject;
}


#pragma mark - Delegate callbacks:

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    STFail(@"failed to publish service. %@", errorDict);
}

@end


#pragma mark -

static void
_WaitUntil(id self, const char *stringified, BOOL(^condition)(void))
{
    NSTimeInterval timeout = NSDate.timeIntervalSinceReferenceDate + TIMEOUT;
    do {
        if (condition()) {
            return;
        }
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, NO);
    } while (NSDate.timeIntervalSinceReferenceDate < timeout);
    
    STFail(@"Timed out waiting for %s", stringified);
}
