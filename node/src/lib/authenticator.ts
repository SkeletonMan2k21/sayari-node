import {  Request, Response } from 'express';
import bcrypt from 'bcrypt';
import { PrismaClient } from '@prisma/client'

export class Authenticator
{
    protected request: Request;
    protected prisma: PrismaClient;

    public constructor(req: Request)
    {
        this.request = req;
        this.prisma = new PrismaClient();
    }

    public authenticate(): void
    {
        const cryptedPass: string = '$2a$12$E.P1TdlUw.NcfwDKVatkz.D2GnTF/15rxPISVMCtXNzF81m9w8rNa';
        const inputPass: string = 'foobar1';

        bcrypt.compare(inputPass, cryptedPass, (err, result) => {
            if (err) {
                // Handle error
                console.error('Error comparing passwords:', err);
                return;
            }

            if (result) {
                // Passwords match, authentication successful
                console.log('Passwords match! User authenticated.');
            } else {
                // Passwords don't match, authentication failed
                console.log('Passwords do not match! Authentication failed.');
            }
        });

        this.lookupUser();
    }

    private async lookupUser()
    {
        const user = await this.prisma.user.findUnique({
            where: {
              email: 'john@smith.com',
            }
        });

        console.log(user);
    }
}