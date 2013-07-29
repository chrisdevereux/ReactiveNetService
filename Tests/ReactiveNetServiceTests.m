//
//  ReactiveNetServiceTests.m
//  ReactiveNetService
//
//  Created by Chris Devereux on 29/07/2013.
//
//

#import <SenTestingKit/SenTestingKit.h>
#import "NSNetService+ReactiveNetService.h"

#define TIMEOUT 5

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

- (void)testBrowsingForServices
{
    __block RACSequence *services;
    RACDisposable *disposable = [[NSNetService rac_servicesOfType:_type inDomain:@"local"] subscribeNext:^(id x) {
        services = x;
    }];
    
    @try {
        WaitUntil(services.array.count == 1);
        STAssertEqualObjects([services.head name], @"Test Service", nil);
    }
    @finally {
        [disposable dispose];
    }
}

- (void)testResolvingServices
{
    NSNetService *service = [self waitForServiceWithName:@"Test Service"];
    __block NSNetService *resolved;
    
    [[service rac_resolveWithTimeout:10] subscribeNext:^(NSNetService *x) {
        resolved = x;
    }];
    
    WaitUntil(resolved != nil);
    
    STAssertEquals(resolved, service, nil);
    STAssertNotNil(resolved.hostName, nil);
}


#pragma mark - Delegate callbacks:

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    STFail(@"failed to publish service. %@", errorDict);
}

@end

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
