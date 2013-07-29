//
//  NSNetService+ReactiveNetService.h
//  ReactiveNetService
//
//  Created by Chris Devereux on 29/07/2013.
//
//

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface NSNetService (ReactiveNetService)

/**
 Returns a signal of RACSequences, each containing the last known availible services
 of type @e type in domain @e domainString.
 
 The subcription continues until the returned signal is cancelled.
*/
+ (RACSignal *)rac_servicesOfType:(NSString *)type inDomain:(NSString *)domainString;

/**
 Returns a signal of RACSequences, each containing the last known availible services
 of type @e type in domain @e domainString.
 
 The signals are resolved before being sent, so the last signal value represents all
 services with a known address.
*/
+ (RACSignal *)rac_resolvedServicesOfType:(NSString *)type inDomain:(NSString *)domainString;

/**
 Resolves the receiver and sends the receiver via the returned signal when the service
 resolves.
*/
- (RACSignal *)rac_resolveWithTimeout:(NSTimeInterval)timeout;

@end

OBJC_EXTERN NSString *const RACNetServiceErrorDomain;
OBJC_EXTERN NSString *const RACNetServiceSystemErrorDomain;
