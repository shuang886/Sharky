//
//  SharkUSBHID.h
//  Sharky
//
//  Created by Steven Huang on 9/15/23.
//

#ifndef SharkUSBHID_h
#define SharkUSBHID_h

int sharkOpen(void);
int sharkCommand(int argc, char **argv);
void sharkClose(void);

#endif /* SharkUSBHID_h */
