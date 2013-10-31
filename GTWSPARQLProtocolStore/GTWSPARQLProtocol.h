#include <libxml/parser.h>
#import <Foundation/Foundation.h>
#import <GTWSWBase/GTWSWBase.h>

@interface GTWSPARQLProtocolStore : NSObject<GTWTripleStore>

@property NSString* endpoint;

- (GTWSPARQLProtocolStore*) initWithEndpoint: (NSString*) endpoint;
+ (unsigned)interfaceVersion;
- (instancetype) initWithDictionary: (NSDictionary*) dictionary;

@end
