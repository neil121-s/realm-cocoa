////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#import "TestUtils.h"
#import "RLMAssertions.h"

#import <Realm/Realm.h>
#import <Realm/RLMSchema_Private.h>

#import "RLMRealmUtil.hpp"

#include <Availability.h>

static void recordFailure(XCTestCase *self, NSString *message, NSString *fileName, NSUInteger lineNumber) {
#ifndef __MAC_10_16
    [self recordFailureWithDescription:message inFile:fileName atLine:lineNumber expected:NO];
#else
    XCTSourceCodeLocation *loc = [[XCTSourceCodeLocation alloc] initWithFilePath:fileName lineNumber:lineNumber];
    XCTIssue *issue = [[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
                                  compactDescription:message
                                 detailedDescription:nil
                                   sourceCodeContext:[[XCTSourceCodeContext alloc] initWithLocation:loc]
                                     associatedError:nil
                                         attachments:@[]];
    [self recordIssue:issue];
#endif
}

void RLMAssertThrowsWithReasonMatchingSwift(XCTestCase *self,
                                            __attribute__((noescape)) dispatch_block_t block,
                                            NSString *regexString, NSString *message,
                                            NSString *fileName, NSUInteger lineNumber) {
    BOOL didThrow = NO;
    @try {
        block();
    }
    @catch (NSException *e) {
        didThrow = YES;
        NSString *reason = e.reason;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString options:(NSRegularExpressionOptions)0 error:nil];
        if ([regex numberOfMatchesInString:reason options:(NSMatchingOptions)0 range:NSMakeRange(0, reason.length)] == 0) {
            NSString *msg = [NSString stringWithFormat:@"The given expression threw an exception with reason '%@', but expected to match '%@'",
                             reason, regexString];
            recordFailure(self, msg, fileName, lineNumber);
        }
    }
    if (!didThrow) {
        NSString *prefix = @"The given expression failed to throw an exception";
        message = message ? [NSString stringWithFormat:@"%@ (%@)",  prefix, message] : prefix;
        recordFailure(self, message, fileName, lineNumber);
    }
}

static void assertThrows(XCTestCase *self, dispatch_block_t block, NSString *message,
                         NSString *fileName, NSUInteger lineNumber,
                         NSString *(^condition)(NSException *)) {
    @try {
        block();
        NSString *prefix = @"The given expression failed to throw an exception";
        message = message ? [NSString stringWithFormat:@"%@ (%@)",  prefix, message] : prefix;
        recordFailure(self, message, fileName, lineNumber);
    }
    @catch (NSException *e) {
        if (NSString *failure = condition(e)) {
            recordFailure(self, failure, fileName, lineNumber);
        }
    }
}

void (RLMAssertThrowsWithName)(XCTestCase *self, __attribute__((noescape)) dispatch_block_t block,
                               NSString *name, NSString *message, NSString *fileName, NSUInteger lineNumber) {
    assertThrows(self, block, message, fileName, lineNumber, ^NSString *(NSException *e) {
        if ([name isEqualToString:e.name]) {
            return nil;
        }
        return [NSString stringWithFormat:@"The given expression threw an exception named '%@', but expected '%@'",
                             e.name, name];
    });
}

void (RLMAssertThrowsWithReason)(XCTestCase *self, __attribute__((noescape)) dispatch_block_t block,
                                 NSString *expected, NSString *message, NSString *fileName, NSUInteger lineNumber) {
    assertThrows(self, block, message, fileName, lineNumber, ^NSString *(NSException *e) {
        if ([e.reason rangeOfString:expected].location != NSNotFound) {
            return nil;
        }
        return [NSString stringWithFormat:@"The given expression threw an exception with reason '%@', but expected '%@'",
                             e.reason, expected];
    });
}

void (RLMAssertThrowsWithReasonMatching)(XCTestCase *self, __attribute__((noescape)) dispatch_block_t block,
                                         NSString *regexString, NSString *message,
                                         NSString *fileName, NSUInteger lineNumber) {
    auto regex = [NSRegularExpression regularExpressionWithPattern:regexString
                                                           options:(NSRegularExpressionOptions)0 error:nil];
    assertThrows(self, block, message, fileName, lineNumber, ^NSString *(NSException *e) {
        if ([regex numberOfMatchesInString:e.reason options:(NSMatchingOptions)0 range:{0, e.reason.length}] > 0) {
            return nil;
        }
        return [NSString stringWithFormat:@"The given expression threw an exception with reason '%@', but expected to match '%@'",
                             e.reason, regexString];
    });
}


void (RLMAssertMatches)(XCTestCase *self, __attribute__((noescape)) NSString *(^block)(),
                        NSString *regexString, NSString *message, NSString *fileName, NSUInteger lineNumber) {
    NSString *result = block();
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString options:(NSRegularExpressionOptions)0 error:nil];
    if ([regex numberOfMatchesInString:result options:(NSMatchingOptions)0 range:NSMakeRange(0, result.length)] == 0) {
        NSString *msg = [NSString stringWithFormat:@"The given expression '%@' did not match '%@'%@",
                         result, regexString, message ? [NSString stringWithFormat:@": %@", message] : @""];
        recordFailure(self, msg, fileName, lineNumber);
    }
}

void (RLMAssertExceptionReason)(XCTestCase *self,
                                NSException *exception, NSString *expected, NSString *expression,
                                NSString *fileName, NSUInteger lineNumber) {
    if (!exception) {
        return;
    }
    if ([exception.reason rangeOfString:(expected)].location == NSNotFound) {
        NSString *desc = [NSString stringWithFormat:@"The expression %@ threw an exception with reason '%@', but expected to contain '%@'", expression, exception.reason ?: @"<nil>", expected];
        [self recordFailureWithDescription:desc inFile:fileName atLine:lineNumber expected:NO];
    }
}

bool RLMHasCachedRealmForPath(NSString *path) {
    return RLMGetAnyCachedRealmForPath(path.UTF8String);
}
