import {  Request, Response } from 'express';
import bcrypt from 'bcrypt';

export class Authenticator
{
    protected request: Request;

    public constructor(req: Request)
    {
        this.request = req;
    }

    public authenticate()
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
    }
}